# Copilot Instructions for PSAppDeployToolkit

## Repository Overview

PSAppDeployToolkit is a PowerShell-based, open-source framework for Windows software deployment that integrates seamlessly with existing deployment solutions (Microsoft Intune, SCCM, Tanium, BigFix, etc.). The project is designed to enhance software deployment processes with a battle-tested prescriptive workflow, extensive function library, customizable branded UI, and comprehensive logging.

### Key Repository Information

- **Primary Language:** PowerShell (5.1+ required, .NET Framework 4.7.2+)
- **Secondary Languages:** C# (.NET Framework 4.7.2 and .NET 8.0-windows)
- **Module Functions:** 134+ public functions in `src/PSAppDeployToolkit/Public/`
- **Current Version:** 4.1.0
- **Target Platform:** Windows 10/11 enterprise environments
- **License:** GNU Lesser General Public License

## Build System & Environment Requirements

### Prerequisites
- **Windows Environment Required:** The C# components target Windows-specific frameworks and cannot be built on Linux/macOS
- **PowerShell 5.1+** (PowerShell 7.x compatible)
- **.NET Framework 4.7.2+** for runtime
- **Visual Studio or Build Tools** with MSBuild for C# compilation
- **Git** for source control operations

### Critical Environment Limitations
⚠️ **IMPORTANT:** This project requires Windows for full compilation due to Windows-specific C# dependencies. On non-Windows systems:
- PowerShell modules can be analyzed and tested (limited functionality)
- C# projects will fail to build with error `NETSDK1100: To build a project targeting Windows`
- Use Windows runners in CI/CD or Windows development environments

## Build Process

### 1. Dependency Installation
**Always run the bootstrap script first:**
```powershell
.\actions_bootstrap.ps1
```

This installs required PowerShell modules:
- **Pester 5.7.1** - Testing framework
- **InvokeBuild 5.14.14** - Build automation
- **PSScriptAnalyzer 1.24.0** - Code analysis
- **platyPS 0.14.2** - Documentation generation  
- **Alt3.Docusaurus.Powershell 1.0.37** - Website documentation

### 2. Main Build Command
```powershell
Invoke-Build -File .\src\PSAppDeployToolkit.build.ps1
```

### 3. Build Tasks Available
The build system offers granular control:
- `Clean` - Reset artifacts directory
- `ValidateRequirements` - Check system prerequisites  
- `TestModuleManifest` - Validate PowerShell module manifest
- `DotNetBuild` - Compile C# solutions
- `ImportModuleManifest` - Load module for testing
- `EncodingCheck` - Verify UTF-8 BOM encoding
- `FormattingCheck` - PSScriptAnalyzer Allman formatting
- `ConfigCheck` - Validate ADMX templates match config
- `StringTableCheck` - Verify translation file consistency
- `Analyze` - Run PSScriptAnalyzer rules
- `Test` - Execute Pester unit tests (requires 0% coverage threshold)
- `CreateHelpStart` - Generate documentation files
- `Build` - Create final module artifacts
- `IntegrationTest` - Run integration test suite

### 4. Selective Testing & Development
**For local development/testing without full build:**
```powershell
# Quick test and analyze only
Invoke-Build TestLocal

# Generate help documentation only  
Invoke-Build HelpLocal

# Full build without integration tests
Invoke-Build BuildNoIntegration
```

## Project Architecture & Layout

### Core Directory Structure
```
src/
├── PSAppDeployToolkit/           # Main PowerShell module
│   ├── PSAppDeployToolkit.psd1   # Module manifest (v4.1.0)
│   ├── PSAppDeployToolkit.psm1   # Module entry point
│   ├── Public/                   # 134 exported functions
│   ├── Private/                  # Internal helper functions
│   ├── Config/config.psd1        # Default configuration
│   ├── Strings/                  # Multi-language support
│   ├── Frontend/v3,v4/           # User interface executables
│   ├── ADMX/                     # Group Policy templates
│   └── lib/                      # Compiled C# assemblies
├── PSADT/                        # C# UI components (.NET 8.0-windows)
├── PSADT.Invoke/                 # C# launcher (.NET 4.7.2)
├── Tests/Unit/                   # Pester unit tests
├── Tests/Integration/            # Integration test suite
└── Tools/                        # Build utilities
```

### C# Solutions
1. **PSADT.slnx** - Main UI framework (requires Windows)
2. **PSADT.Invoke.slnx** - Application launcher (requires Windows)

Both solutions use `.slnx` format (Visual Studio 17.0+) and require MSBuild.

## Testing Infrastructure

### Unit Tests (Pester)
- **Location:** `src/Tests/Unit/`
- **Framework:** Pester 5.7.1+
- **Coverage:** JaCoCo XML format, 0% minimum threshold
- **Command:** `Invoke-Build Test`

### Integration Tests
- **Location:** `src/Tests/Integration/`
- **Execution:** Post-build validation
- **Command:** `Invoke-Build IntegrationTest`

### Code Quality
- **PSScriptAnalyzer** rules enforced (Allman formatting)
- **UTF-8 BOM encoding** required for all .ps1 files
- **No PowerShell environment provider** usage allowed (except specific functions)

## Common Build Issues & Workarounds

### 1. PowerShell Repository Issues
**Problem:** `No repository with the name 'PSGallery' was found`
**Solution:** 
```powershell
Register-PSRepository -Default
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

### 2. C# Build Failures on Non-Windows
**Problem:** `NETSDK1100: To build a project targeting Windows`
**Workaround:** Run on Windows environment or skip C# compilation for PowerShell-only changes

### 3. Module Import Issues
**Problem:** `CimCmdlets module not found`
**Solution:** Windows-specific dependency - use Windows PowerShell 5.1 or install Windows Compatibility modules

### 4. PSScriptAnalyzer Formatting
**Problem:** Code formatting violations
**Solution:** 
```powershell
# Auto-fix in development (non-CI)
Invoke-ScriptAnalyzer -Path . -Setting CodeFormattingAllman -Fix
```

### 5. Long Build Times
**Typical durations:**
- Full build: 5-10 minutes
- C# compilation: 2-3 minutes  
- Documentation generation: 1-2 minutes
- Unit tests: 30-60 seconds

## GitHub Actions Workflow

### CI/CD Pipeline
- **Trigger:** Pull requests and pushes to main/develop
- **Runner:** `windows-latest` (required for C# builds)
- **Steps:** Bootstrap → Build → Test → Sign (branches: main/develop/4.0.x)
- **Artifacts:** Module templates (v3/v4), compiled binaries

### Code Signing
Production builds automatically sign assemblies using Azure Key Vault when running on protected branches.

## Validation Steps

### Pre-commit Verification
```powershell
# 1. Bootstrap dependencies
.\actions_bootstrap.ps1

# 2. Run code analysis
Invoke-Build TestLocal

# 3. Check formatting compliance  
Invoke-Build FormattingCheck

# 4. Validate configuration consistency
Invoke-Build ConfigCheck
```

### Manual Verification
```powershell
# Import built module
Import-Module .\src\Artifacts\Module\PSAppDeployToolkit\PSAppDeployToolkit.psd1

# Verify exported functions
Get-Command -Module PSAppDeployToolkit | Measure-Object

# Test basic functionality (Windows only)
New-ADTTemplate -Destination ./temp -Name TestTemplate -Version 4
```

## Key Configuration Files

- **Module Manifest:** `src/PSAppDeployToolkit/PSAppDeployToolkit.psd1`
- **Build Script:** `src/PSAppDeployToolkit.build.ps1`
- **Default Config:** `src/PSAppDeployToolkit/Config/config.psd1`
- **CI Workflow:** `.github/workflows/module-build.yml`
- **Dependencies:** `actions_bootstrap.ps1`

## Working with This Repository

### For PowerShell Changes
1. Edit functions in `src/PSAppDeployToolkit/Public/` or `Private/`
2. Run `Invoke-Build TestLocal` for quick validation
3. Ensure UTF-8 BOM encoding and Allman formatting
4. Add corresponding Pester tests in `src/Tests/Unit/`

### For C# Changes
1. **Requires Windows environment**
2. Edit projects in `src/PSADT/` or `src/PSADT.Invoke/`
3. Run full `Invoke-Build` to compile and copy binaries
4. Binaries auto-copy to `src/PSAppDeployToolkit/lib/` and `Frontend/`

### Documentation Updates
1. Edit PowerShell help in function comment-based help
2. Run `Invoke-Build CreateHelpStart` to regenerate markdown
3. Documentation exports to `src/Artifacts/platyPS/` and `Docusaurus/`

**Trust these instructions** - they are comprehensive and tested. Only search for additional information if you encounter specific errors not covered here or need to understand implementation details beyond the scope of these build and validation instructions.