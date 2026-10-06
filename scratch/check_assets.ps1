Add-Type -AssemblyName System.Drawing
$files = @(
  'assets/farm_rpg/tileset/ext/Big old Tree.png',
  'assets/farm_rpg/tileset/ext/Tree Deep Forest.png',
  'assets/farm_rpg/tileset/ext/Fantasy Mushroom.png',
  'assets/farm_rpg/tileset/ext/bushes.png',
  'assets/farm_rpg/objects/exterior/Road.png',
  'assets/farm_rpg/tileset/ext/Tileset Grass Cliff Tileset Spring.png',
  'assets/farm_rpg/tileset/ext/ALL props seasons.png',
  'assets/farm_rpg/tileset/ext/Bridge.png'
)
foreach ($f in $files) {
    if (Test-Path $f) {
        $img = [System.Drawing.Image]::FromFile((Resolve-Path $f))
        Write-Host "$f : $($img.Width) x $($img.Height)"
        $img.Dispose()
    }
}
