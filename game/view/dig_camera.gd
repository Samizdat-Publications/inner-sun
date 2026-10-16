class_name DigCamera
extends RefCounted
## The drilling camera's numbers, kept apart from Main so they can be tested: the zoom range, the
## wheel step, and where the crown sits in the free world area. About 20 m of rock across the world
## area by default (item 1 of the M1b dig-view spec), the whole tower in view, rock below the crown.

const ZOOM_MIN: float = 0.45
const ZOOM_MAX: float = 1.15
const STEP: float = 1.1  ## One wheel notch multiplies or divides the zoom by this.
const VIEW_WIDTH_M: float = 20.0
const FRAC_MIN: float = 0.3  ## The crown is never higher than this fraction of the area's height.
const FRAC_MAX: float = 0.78
const TOP_MARGIN_PX: float = 40.0  ## Air kept above the tower's roof when the whole tower fits.


## The default zoom: `area_w_px` of world area shows VIEW_WIDTH_M of rock at `ppm`.
static func default_zoom(area_w_px: float, ppm: float) -> float:
	return clampf(area_w_px / (VIEW_WIDTH_M * ppm), ZOOM_MIN, ZOOM_MAX)


static func clamp_zoom(z: float) -> float:
	return clampf(z, ZOOM_MIN, ZOOM_MAX)


## One wheel notch: dir > 0 zooms in, dir < 0 zooms out.
static func stepped(z: float, dir: int) -> float:
	return clamp_zoom(z * (STEP if dir > 0 else 1.0 / STEP))


## Where the crown (the tower's bottom edge) sits down the world area, as a fraction of its height:
## low enough that the whole tower shows when it fits, never above the upper third.
static func crown_frac(ship_h_px: float, area_h_px: float, zoom: float) -> float:
	var view_h: float = area_h_px / maxf(zoom, 0.01)
	return clampf((ship_h_px + TOP_MARGIN_PX) / view_h, FRAC_MIN, FRAC_MAX)


## The world point that belongs at the centre of the world area, for a crown at (crown_x, crown_y).
static func center_for(crown_x: float, crown_y: float, ship_h_px: float, area_h_px: float, zoom: float) -> Vector2:
	var f: float = crown_frac(ship_h_px, area_h_px, zoom)
	return Vector2(crown_x, crown_y - (f - 0.5) * area_h_px / maxf(zoom, 0.01))
