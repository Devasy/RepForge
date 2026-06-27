import sys
import zipfile
import tempfile
import os
import shutil

def get_elf_build_id_info(data):
    if not data.startswith(b"\x7fELF"):
        return None
    
    # Parse 32-bit vs 64-bit ELF
    elf_class = data[4]
    is_32 = elf_class == 1
    
    if is_32:
        shoff = int.from_bytes(data[32:36], 'little')
        shentsize = int.from_bytes(data[46:48], 'little')
        shnum = int.from_bytes(data[48:50], 'little')
        shstrndx = int.from_bytes(data[50:52], 'little')
    else:
        shoff = int.from_bytes(data[40:48], 'little')
        shentsize = int.from_bytes(data[58:60], 'little')
        shnum = int.from_bytes(data[60:62], 'little')
        shstrndx = int.from_bytes(data[62:64], 'little')
        
    str_sec_offset = shoff + shstrndx * shentsize
    if is_32:
        str_offset = int.from_bytes(data[str_sec_offset+16:str_sec_offset+20], 'little')
    else:
        str_offset = int.from_bytes(data[str_sec_offset+24:str_sec_offset+32], 'little')
        
    for i in range(shnum):
        sec_offset = shoff + i * shentsize
        name_offset = int.from_bytes(data[sec_offset:sec_offset+4], 'little')
        
        if is_32:
            offset = int.from_bytes(data[sec_offset+16:sec_offset+20], 'little')
            size = int.from_bytes(data[sec_offset+20:sec_offset+24], 'little')
        else:
            offset = int.from_bytes(data[sec_offset+24:sec_offset+32], 'little')
            size = int.from_bytes(data[sec_offset+32:sec_offset+40], 'little')
            
        # Read name
        idx = str_offset + name_offset
        name = b''
        while idx < len(data) and data[idx] != 0:
            name += bytes([data[idx]])
            idx += 1
        name = name.decode('utf-8', errors='ignore')
        
        if name == ".note.gnu.build-id":
            # Search for the actual build-id descriptor inside the section
            # Format: [namesz (4 bytes)][descsz (4 bytes)][type (4 bytes)][name][desc]
            sec_data = data[offset : offset + size]
            if len(sec_data) >= 16:
                namesz = int.from_bytes(sec_data[0:4], 'little')
                descsz = int.from_bytes(sec_data[4:8], 'little')
                type_id = int.from_bytes(sec_data[8:12], 'little')
                if type_id == 3: # NT_GNU_BUILD_ID
                    # Align to 4 bytes for name
                    name_aligned_sz = (namesz + 3) & ~3
                    build_id_offset = offset + 12 + name_aligned_sz
                    return {
                        'offset': build_id_offset,
                        'size': descsz,
                        'value': data[build_id_offset : build_id_offset + descsz]
                    }
    return None

def patch_so_data(built_so_data, ref_so_data):
    if len(built_so_data) != len(ref_so_data):
        print(f"[-] Sizes differ: Built={len(built_so_data)}, Ref={len(ref_so_data)}")
        return None
        
    built_info = get_elf_build_id_info(built_so_data)
    ref_info = get_elf_build_id_info(ref_so_data)
    
    if not built_info or not ref_info:
        print("[-] Build-ID section not found in one of the SO files")
        return None
        
    if built_info['size'] != ref_info['size']:
        print(f"[-] Build-ID size mismatch: Built={built_info['size']}, Ref={ref_info['size']}")
        return None
        
    # Replace the build-id bytes in the built SO with the reference ones
    so_mutable = bytearray(built_so_data)
    start = built_info['offset']
    end = start + built_info['size']
    so_mutable[start:end] = ref_info['value']
    patched_data = bytes(so_mutable)
    
    # Check if they are now 100% identical
    if patched_data == ref_so_data:
        print("[+] Patched SO matches reference SO exactly!")
        return patched_data
    else:
        # Check if there are other differences
        diffs = [i for i in range(len(patched_data)) if patched_data[i] != ref_so_data[i]]
        print(f"[-] Patched SO still differs from reference at {len(diffs)} positions.")
        return None

def patch_apk(built_apk, ref_apk, output_apk):
    temp_dir = tempfile.mkdtemp()
    try:
        if os.path.abspath(built_apk) != os.path.abspath(output_apk):
            shutil.copy2(built_apk, output_apk)
        
        # Open both to extract and patch SO files
        with zipfile.ZipFile(ref_apk, 'r') as z_ref:
            ref_so_entries = {name: z_ref.read(name) for name in z_ref.namelist() if name.endswith(".so")}
            
        with zipfile.ZipFile(built_apk, 'r') as z_built:
            built_so_entries = {name: z_built.read(name) for name in z_built.namelist() if name.endswith(".so")}
            
        patched_entries = {}
        for name, built_data in built_so_entries.items():
            if name in ref_so_entries:
                print(f"[+] Found shared library in both: {name}")
                ref_data = ref_so_entries[name]
                patched_data = patch_so_data(built_data, ref_data)
                if patched_data:
                    patched_entries[name] = patched_data
                    
        if not patched_entries:
            print("[-] No patchable SO files found or patching failed.")
            return False
            
        # Recreate the APK with patched entries
        tmp_apk_path = os.path.join(temp_dir, "patched.apk")
        with zipfile.ZipFile(built_apk, 'r') as zin:
            with zipfile.ZipFile(tmp_apk_path, 'w', zipfile.ZIP_DEFLATED) as zout:
                for item in zin.infolist():
                    if item.filename in patched_entries:
                        print(f"[+] Writing patched entry: {item.filename}")
                        zout.writestr(item, patched_entries[item.filename])
                    else:
                        zout.writestr(item, zin.read(item.filename))
                        
        shutil.copy2(tmp_apk_path, output_apk)
        print(f"[+] Successfully generated patched APK: {output_apk}")
        return True
    finally:
        shutil.rmtree(temp_dir)

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python patch_so.py <built_apk> <reference_apk> <output_apk>")
        sys.exit(1)
    success = patch_apk(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if success else 1)
