# Technical Debt & Optimization Backlog

*Last Updated: 2025-09-20*
*Based on: Container log analysis after full end-to-end testing*

## 🎯 Overview

This document tracks technical debt and optimization opportunities identified during container log analysis. The application is **fully functional and production-ready**, but these items should be addressed for optimal performance and future compatibility.

## ✅ Recently Resolved

- ✅ **esbuild Security Vulnerability**: Automatically resolved via package override (`>=0.25.0`)
- ✅ **Outdated Dependencies**: Automatic updates during setup process
- ✅ **Browserslist Database**: Auto-refresh to latest browser compatibility data
- ✅ **Deprecated Dependencies**: Identified and tracked (glob, inflight)

## 🔴 High Priority (Next.js 16 Compatibility)

### 1. Next.js Image Quality Configuration
**Issue**: Images using quality="100" not configured in `images.qualities`
```
Image with src "..." is using quality "100" which is not configured in images.qualities.
This config will be required starting in Next.js 16.
```
**Impact**: Will break in Next.js 16
**Solution**: Add quality="100" to Next.js image configuration
**File**: `next.config.ts`

### 2. Cross-Origin Request Configuration
**Issue**: Cross-origin requests detected without explicit configuration
```
Cross origin request detected from 192.168.0.161 to /_next/* resource.
In a future major version of Next.js, you will need to explicitly configure "allowedDevOrigins"
```
**Impact**: Future Next.js versions will require explicit configuration
**Solution**: Add `allowedDevOrigins` to next.config.js
**File**: `next.config.ts`

### 3. Webpack/Turbopack Configuration Conflict
**Issue**: Webpack configured while Turbopack is active
```
Webpack is configured while Turbopack is not, which may cause problems.
```
**Impact**: Potential build/development issues
**Solution**: Configure Turbopack properly or adjust Webpack config
**File**: `next.config.ts`

## 🟡 Medium Priority (Infrastructure)

### 4. Node.js Version Upgrade
**Issue**: Using Node.js v18.20.8, some packages expect >=20.18.1
```
npm warn EBADENGINE Unsupported engine {
  package: 'undici@7.10.0',
  required: { node: '>=20.18.1' },
  current: { node: 'v18.20.8', npm: '10.8.2' }
}
```
**Impact**: Package compatibility warnings, potential future issues
**Solution**: Upgrade Docker base image to Node.js 20+
**File**: `data/payloadcms/Dockerfile.dev`

### 5. Sharp Version Regression
**Issue**: Sharp installation downgrading from 0.34.4 to 0.32.6
```
+ sharp 0.32.6 (0.34.4 is available)
- sharp 0.32.6
```
**Impact**: Missing latest sharp performance improvements
**Solution**: Fix Alpine Linux sharp installation process
**File**: `data/payloadcms/docker-entrypoint.dev.sh`

### 6. Remaining Security Vulnerabilities
**Issue**: 6 vulnerabilities still present after audit fix
```
6 vulnerabilities (1 low, 5 moderate)
To address issues that do not require attention, run: npm audit fix
```
**Impact**: Potential security risks
**Solution**: Manual review and resolution of remaining vulnerabilities
**Command**: `npm audit` for details

## 🟢 Low Priority (Maintenance)

### 7. Outdated Packages
**Packages with newer versions available**:
- `lucide-react`: 0.378.0 → 0.544.0
- `react-hook-form`: 7.45.4 → 7.63.0
- `tailwind-merge`: 2.6.0 → 3.3.1
- `@types/react`: 19.0.7 → 19.1.13
- `eslint-config-next`: 15.1.5 → 15.5.3
- `tailwindcss`: 3.4.17 → 4.1.13 (major version)

**Impact**: Missing latest features and bug fixes
**Solution**: Update during regular maintenance cycles
**Note**: Tailwind v4 is a major version requiring migration

### 8. NPM Version Update
**Issue**: NPM v10.8.2 available, v11.6.0 latest
```
npm notice New major version of npm available! 10.8.2 -> 11.6.0
```
**Impact**: Missing latest npm features
**Solution**: Update npm in Docker image
**File**: `data/payloadcms/Dockerfile.dev`

## 🔄 Expected Warnings (No Action Required)

These warnings are expected and **do not affect functionality**:

- **Peer Dependency Mismatches**: React 19.1.1 vs expected 16-18 (packages will catch up)
- **Deprecated Subdependencies**: `glob@7.2.3`, `inflight@1.0.6` (transitive dependencies)
- **Build Script Restrictions**: pnpm ignoring esbuild, sharp, unrs-resolver (expected behavior)

## 📊 Implementation Timeline

### Phase 1: Next.js 16 Preparation (Before Next.js 16 Upgrade)
- [ ] Configure image quality settings
- [ ] Add allowedDevOrigins configuration
- [ ] Resolve Webpack/Turbopack conflict

### Phase 2: Infrastructure Improvements (Next Maintenance Window)
- [ ] Upgrade to Node.js 20+
- [ ] Fix sharp version regression
- [ ] Address remaining security vulnerabilities

### Phase 3: Regular Maintenance (Quarterly)
- [ ] Update outdated packages (excluding major versions)
- [ ] NPM version update
- [ ] Review and update this tech debt document

## 🛠️ Commands for Resolution

```bash
# Check current versions
docker compose exec payloadcms-app pnpm outdated

# Security audit details
docker compose exec payloadcms-app npm audit

# Update specific packages
docker compose exec payloadcms-app pnpm update [package-name]

# Manual sharp installation fix
docker compose exec payloadcms-app npm install --platform=linuxmusl --arch=x64 sharp@latest
```

## 📝 Notes

- **Application Status**: Fully functional and production-ready
- **Testing Status**: All pages load correctly, admin interface functional, seeding works
- **Priority**: Focus on High Priority items for Next.js 16 compatibility
- **Automation**: Our dependency optimization changes are working correctly and resolved the major esbuild security vulnerability automatically