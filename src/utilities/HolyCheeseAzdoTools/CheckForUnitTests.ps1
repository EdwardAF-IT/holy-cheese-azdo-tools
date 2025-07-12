$sourceDir = "C:\Code\holy-cheese\src\utilities\HolyCheeseAzdoTools\TagTools"
$testDir = "C:\Code\holy-cheese\src\utilities\HolyCheeseAzdoTools.UnitTests\TagTools"

New-Item -Path $testDir -ItemType Directory -Force | Out-Null

$classPattern = 'public\s+class\s+(\w+)'
$methodPattern = 'public\s+(?:async\s+)?(?:\w+\s+)?(\w+)\s*\('

Get-ChildItem -Path $sourceDir -Filter *.cs | ForEach-Object {
    $sourcePath = $_.FullName
    $sourceContent = Get-Content $sourcePath -Raw

    if ($sourceContent -match $classPattern) {
        $className = $matches[1]
        $testClassName = "${className}_UnitTests"
        $testFileName = "${testClassName}.cs"
        $testFilePath = Join-Path $testDir $testFileName
                
        if (Test-Path $testFilePath) {
            Write-Host "Skipped unit test file creation (already exists): $testFileName"
            return
        }

        $methods = [regex]::Matches($sourceContent, $methodPattern) | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique

        $testClassContent = @'
using System;
using Xunit;

namespace HolyCheeseAzdoTools.UnitTests.TagTools
{
    public class CLASSNAME
    {
'@
        $testClassContent = $testClassContent -replace 'CLASSNAME', $testClassName

        foreach ($method in $methods) {
            $methodStub = @'

        [Fact]
        public void METHODNAME_ShouldBehaveAsExpected()
        {
            // TODO: Arrange, Act, Assert
            throw new Exception("Implement test for METHODNAME");
        }

'@
            $methodStub = $methodStub -replace 'METHODNAME', $method
            $testClassContent += $methodStub
        }

        $testClassContent += @'
    }
}
'@

        Set-Content -Path $testFilePath -Value $testClassContent
        Write-Host "Created: $testFileName with $($methods.Count) test stub(s)"
    } else {
        Write-Host "Skipped unit test file creation (no public class found): $($_.Name)"
    }
}
