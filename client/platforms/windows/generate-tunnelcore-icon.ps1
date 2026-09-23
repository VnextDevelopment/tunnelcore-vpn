param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Output
)

Add-Type -AssemblyName System.Drawing

$image = [System.Drawing.Image]::FromFile($Source)
try {
    $bitmap = New-Object System.Drawing.Bitmap 256, 256
    try {
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        try {
            $graphics.Clear([System.Drawing.Color]::Transparent)
            $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $graphics.DrawImage($image, 0, 0, 256, 256)
        }
        finally {
            $graphics.Dispose()
        }

        $iconHandle = $bitmap.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($iconHandle)
        try {
            $stream = [System.IO.File]::Open($Output, [System.IO.FileMode]::Create)
            try {
                $icon.Save($stream)
            }
            finally {
                $stream.Dispose()
            }
        }
        finally {
            $icon.Dispose()
        }
    }
    finally {
        $bitmap.Dispose()
    }
}
finally {
    $image.Dispose()
}
