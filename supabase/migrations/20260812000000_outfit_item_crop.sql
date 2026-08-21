-- Per-item crop for saved outfits.
--
-- The canvas editor lets you drag a handle on an item to crop it. Crop is a
-- separate transform from scale/rotation: it hides pixels rather than resizing
-- the item, so it needs its own storage alongside the existing canvas_* columns.
--
-- Stored as fractions of the item's canvas_size box, matching Flutter's
-- Rect.fromLTRB. (0, 0, 1, 1) means "not cropped", which is why every existing
-- row backfills to exactly that and why the defaults let older clients keep
-- inserting rows without knowing these columns exist.

alter table public.outfit_items
  add column if not exists canvas_crop_l double precision not null default 0,
  add column if not exists canvas_crop_t double precision not null default 0,
  add column if not exists canvas_crop_r double precision not null default 1,
  add column if not exists canvas_crop_b double precision not null default 1;

-- Guard against inside-out or out-of-bounds rects reaching the renderer.
-- Previews trust these values to clip with, so a bad row would silently draw
-- nothing rather than fail loudly.
alter table public.outfit_items
  drop constraint if exists outfit_items_canvas_crop_bounds;

alter table public.outfit_items
  add constraint outfit_items_canvas_crop_bounds check (
    canvas_crop_l >= 0 and canvas_crop_r <= 1 and canvas_crop_l < canvas_crop_r
    and canvas_crop_t >= 0 and canvas_crop_b <= 1 and canvas_crop_t < canvas_crop_b
  );
