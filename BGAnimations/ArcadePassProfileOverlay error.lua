-- ScreenSystemLayer::Init loads an "error" element for every instance; the
-- fallback theme provides one for ScreenSystemLayer itself. This overlay has
-- no per-side error content, so return an empty actor frame.
return Def.ActorFrame {}
