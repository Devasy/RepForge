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

import zlib

def find_cd_header_offset(data, filename):
    fname_bytes = filename.encode('utf-8')
    idx = 0
    while True:
        idx = data.find(b"\x50\x4b\x01\x02", idx)
        if idx == -1:
            break
        fn_len = int.from_bytes(data[idx+28:idx+30], 'little')
        if fn_len == len(fname_bytes):
            if data[idx+46 : idx+46+fn_len] == fname_bytes:
                return idx
        idx += 4
    return -1

def patch_apk(built_apk, ref_apk, output_apk):
    try:
        if os.path.abspath(built_apk) != os.path.abspath(output_apk):
            shutil.copy2(built_apk, output_apk)
        
        with open(output_apk, "rb") as f:
            apk_data = bytearray(f.read())
            
        with zipfile.ZipFile(ref_apk, 'r') as z_ref:
            ref_so_entries = {name: z_ref.read(name) for name in z_ref.namelist() if name.endswith(".so")}
            
        with zipfile.ZipFile(output_apk, 'r') as z_built:
            built_so_entries = {}
            built_so_info = {}
            for info in z_built.infolist():
                if info.filename.endswith(".so"):
                    built_so_entries[info.filename] = z_built.read(info)
                    built_so_info[info.filename] = info
                    
        patched_count = 0
        for name, built_data in built_so_entries.items():
            if name in ref_so_entries:
                print(f"[+] Found shared library in both: {name}")
                ref_data = ref_so_entries[name]
                patched_so = patch_so_data(built_data, ref_data)
                if patched_so:
                    info = built_so_info[name]
                    if info.compress_type != 0:
                        print(f"[-] Shared library {name} is compressed. In-place patching is not supported.")
                        return False
                        
                    new_crc = zlib.crc32(patched_so) & 0xffffffff
                    local_header_offset = info.header_offset
                    local_extra_len = int.from_bytes(apk_data[local_header_offset+28 : local_header_offset+30], 'little')
                    filename_len = len(name.encode('utf-8'))
                    
                    data_offset = local_header_offset + 30 + filename_len + local_extra_len
                    print(f"[+] Writing patched SO to APK data offset: {hex(data_offset)}")
                    apk_data[data_offset : data_offset + len(patched_so)] = patched_so
                    
                    print(f"[+] Updating Local Header CRC-32 to: {hex(new_crc)}")
                    apk_data[local_header_offset+14 : local_header_offset+18] = new_crc.to_bytes(4, 'little')
                    
                    cd_offset = find_cd_header_offset(apk_data, name)
                    if cd_offset == -1:
                        print(f"[-] Could not find Central Directory Header for {name}")
                        return False
                        
                    print(f"[+] Updating Central Directory CRC-32 to: {hex(new_crc)}")
                    apk_data[cd_offset+16 : cd_offset+20] = new_crc.to_bytes(4, 'little')
                    patched_count += 1
                    
        if patched_count == 0:
            print("[-] No patchable SO files found or patching failed.")
            return False
            
        with open(output_apk, "wb") as f:
            f.write(apk_data)
            
        print(f"[+] Successfully patched APK in-place: {output_apk}")
        return True
    except Exception as e:
        print(f"[-] Exception occurred during patching: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    if len(sys.argv) < 4:
        print("Usage: python patch_so.py <built_apk> <reference_apk> <output_apk>")
        sys.exit(1)
    success = patch_apk(sys.argv[1], sys.argv[2], sys.argv[3])
    sys.exit(0 if success else 1)
