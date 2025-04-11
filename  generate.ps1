# Set variables
$solutionName = "PromptStudio.Backend"
$remoteRepo = "https://github.com/a-tsygankov/PromptVCS.Backend.git"

# Create root and src directories
$folders = @(
    "$solutionName/src/PromptStudio.API",
    "$solutionName/src/PromptStudio.Application",
    "$solutionName/src/PromptStudio.Domain",
    "$solutionName/src/PromptStudio.Infrastructure",
    "$solutionName/src/PromptStudio.Persistence",
    "$solutionName/src/PromptStudio.SharedKernel",
    "$solutionName/src/PromptStudio.EventSourcing",
    "$solutionName/tests/PromptStudio.UnitTests",
    "$solutionName/tests/PromptStudio.IntegrationTests",
    "$solutionName/build/scripts",
    "$solutionName/build/tools"
)

Write-Host "Creating directories..."
$folders | ForEach-Object { New-Item -ItemType Directory -Path $_ -Force }

# Create .csproj files with net8.0
$projects = @(
    "PromptStudio.API",
    "PromptStudio.Application",
    "PromptStudio.Domain",
    "PromptStudio.Infrastructure",
    "PromptStudio.Persistence",
    "PromptStudio.SharedKernel",
    "PromptStudio.EventSourcing"
)

Write-Host "Creating .csproj files..."
foreach ($proj in $projects) {
    $projPath = "$solutionName/src/$proj/$proj.csproj"
    New-Item -Path $projPath -ItemType File -Force | Out-Null
    Add-Content -Path $projPath -Value "<Project Sdk=`"Microsoft.NET.Sdk`">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>
</Project>"
}

# Initialize Git repo
Write-Host "Initializing git repository..."
Set-Location $solutionName
git init
git remote add origin $remoteRepo

# Create initial README and .gitignore
Set-Content -Path "README.md" -Value "# $solutionName"
Set-Content -Path ".gitignore" -Value @"
bin/
obj/
*.user
.vscode/
*.suo
*.DS_Store
"@

# Stage, commit and push
git add .
git commit -m "Initial commit with .NET 8 structure and projects"
git branch -M main
git push -u origin main

Write-Host "✅ Done. .NET 8 project initialized and pushed to GitHub."
