# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- **Improved blink.cmp integration** - Now uses official Provider Override API instead of internal patching
- **Better reliability** - Removed timing-dependent code, zero race conditions
- **Enhanced error handling** - Added comprehensive nil checks and pcall protection
- **Updated documentation** - Clearer examples and configuration guide

### Fixed

- Fixed buffer context detection in transform_items (was checking wrong buffer)
- Added safety checks for nil context/items
- Added error handling for TreeSitter operations

### Technical Improvements

- Simplified blink.lua module to use helper functions only
- Removed auto-integration logic from init.lua
- Better code maintainability and future-proofing
- Uses stable blink.cmp APIs throughout

---

## [1.0.0] - Initial Release

### Added

- TreeSitter injection for CSS syntax highlighting in styled-components
- Native CSS LSP support via cssls
- Custom blink.cmp completion source
- Support for styled.*, css, createGlobalStyle, and keyframes
- Comprehensive documentation

### Features

- Zero-config setup for LazyVim users
- Smart CSS completion filtering
- Performance optimizations (context detection caching)
- Compatible with Neovim 0.10+ and 0.11+

[Unreleased]: https://github.com/crafts69guy/styled-components.nvim/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/crafts69guy/styled-components.nvim/releases/tag/v1.0.0
