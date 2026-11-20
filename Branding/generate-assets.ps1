# Regenerate PNG assets from the editable SVG rectangles. Windows / PowerShell.
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
[xml]$svg=Get-Content -Raw (Join-Path $PSScriptRoot 'BEAT4.svg')
function Render([int]$size,[string]$path){
 $bmp=[Drawing.Bitmap]::new($size,$size,[Drawing.Imaging.PixelFormat]::Format24bppRgb)
 $g=[Drawing.Graphics]::FromImage($bmp)
 foreach($rect in $svg.SelectNodes('//*[local-name()="rect"]')){
  $fill=$rect.GetAttribute('fill');if(!$fill){$fill=$rect.ParentNode.GetAttribute('fill')}
  $b=[Drawing.SolidBrush]::new([Drawing.ColorTranslator]::FromHtml($fill))
  $x=[double]$rect.GetAttribute('x')*$size/1024;$y=[double]$rect.GetAttribute('y')*$size/1024
  $w=[double]$rect.GetAttribute('width')*$size/1024;$h=[double]$rect.GetAttribute('height')*$size/1024
  $left=[int][Math]::Round($x);$top=[int][Math]::Round($y)
  $g.FillRectangle($b,$left,$top,[int][Math]::Round($x+$w)-$left,[int][Math]::Round($y+$h)-$top)
  $b.Dispose()
 }
 $bmp.Save($path,[Drawing.Imaging.ImageFormat]::Png);$g.Dispose();$bmp.Dispose()
}
foreach($set in 'AppIcon.appiconset','BEAT4Logo.imageset'){
 $dir=Join-Path $PSScriptRoot "Assets.xcassets\$set"
 $contents=Get-Content -Raw (Join-Path $dir 'Contents.json')|ConvertFrom-Json
 foreach($entry in $contents.images){
  $points=if($entry.size){[double]::Parse($entry.size.Split('x')[0],[Globalization.CultureInfo]::InvariantCulture)}else{128}
  Render ([int]($points*[int]$entry.scale.TrimEnd('x'))) (Join-Path $dir $entry.filename)
 }
}