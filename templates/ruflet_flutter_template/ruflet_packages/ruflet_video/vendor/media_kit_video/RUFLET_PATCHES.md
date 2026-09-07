# Ruflet patches to media_kit_video 2.0.1

Upstream: https://github.com/media-kit/media-kit, MIT license in LICENSE.

The native playback implementation is unchanged. SubtitleView uses a neutral
DefaultTextStyle instead of Material, and fullscreen uses a ColoredBox with the
configured video fill. The fullscreen theme injector only copies control themes
that actually exist in the source context. This allows the Ruflet Cupertino video
renderer to use subtitles and fullscreen without mounting Material widgets.

Material controls remain available for the Material renderer. Ruflet chooses its
renderer from the page platform instead of upstream AdaptiveVideoControls.
