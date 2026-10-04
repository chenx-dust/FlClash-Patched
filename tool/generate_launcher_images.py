import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SVG_NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', SVG_NS)


def main():
    for command in ('rsvg-convert', 'magick'):
        if not shutil.which(command):
            raise SystemExit(f'{command} is required')
    icon = ET.parse(ROOT / 'assets/images/icon.svg').getroot()
    paths = ''.join(ET.tostring(path, encoding='unicode') for path in icon)

    with tempfile.TemporaryDirectory(prefix='flclash-launchers-') as directory:
        temporary = Path(directory)

        def render(body, destination, size, viewport=240):
            source = temporary / 'icon.svg'
            source.write_text(
                f'<svg xmlns="{SVG_NS}" viewBox="0 0 {viewport} {viewport}">'
                f'{body}</svg>',
            )
            output = temporary / 'icon.png'
            subprocess.run([
                'rsvg-convert', '-w', str(size), '-h', str(size),
                '-o', str(output), str(source),
            ], check=True)
            if destination.suffix == '.webp':
                subprocess.run([
                    'magick', str(output), '-define', 'webp:lossless=true',
                    str(destination),
                ], check=True)
            else:
                shutil.copyfile(output, destination)

        launch_body = (
            f'<svg x="90" y="90" width="108" height="108" '
            f'viewBox="0 0 240 240">{paths}</svg>'
        )
        launch = ROOT / 'ios/Runner/Assets.xcassets/LaunchLogo.imageset'
        for destination in sorted(launch.glob('*.png')):
            scale = 3 if '@3x' in destination.name else 2 if '@2x' in destination.name else 1
            render(launch_body, destination, 288 * scale, viewport=288)

        resources = ROOT / 'android/app/src/main/res'
        for density, scale in [('mdpi', 1), ('hdpi', 1.5), ('xhdpi', 2), ('xxhdpi', 3), ('xxxhdpi', 4)]:
            for rounded in (False, True):
                background = (
                    '<circle cx="120" cy="120" r="112" fill="#FAFAFA"/>'
                    if rounded else
                    '<rect x="24" y="24" width="192" height="192" rx="18" fill="#FAFAFA"/>'
                )
                foreground = (
                    f'<g transform="translate(24 24) scale(.8)">{paths}</g>'
                    if rounded else
                    f'<g transform="translate(36 36) scale(.7)">{paths}</g>'
                )
                name = 'ic_launcher_round.webp' if rounded else 'ic_launcher.webp'
                render(background + foreground, resources / f'mipmap-{density}' / name, round(48 * scale))
            render(
                f'<rect width="240" height="240" fill="#FAFAFA"/>{paths}',
                resources / f'mipmap-television-{density}/ic_launcher.webp',
                round(80 * scale),
            )


if __name__ == '__main__':
    main()
