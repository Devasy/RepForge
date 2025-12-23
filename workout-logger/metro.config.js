const { getDefaultConfig } = require('expo/metro-config');

const config = getDefaultConfig(__dirname);

config.resolver.sourceExts.push('wasm');
config.resolver.assetExts = config.resolver.assetExts.filter(ext => ext !== 'wasm');

module.exports = config;
