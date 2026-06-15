#[derive(Clone, Debug, uniffi::Record)]
pub struct HandData {
    /// Normalized X of the pinch point, 0..1 (left edge → right edge of frame).
    pub pinch_x: f64,
    /// Normalized Y of the pinch point, 0..1 (top → bottom of frame).
    pub pinch_y: f64,
    /// Pinch amount, 0..1 (open hand → fully pinched).
    pub pinch: f64,
}

#[derive(Clone, Debug, Default, uniffi::Record)]
pub struct HandsState {
    pub left: Option<HandData>,
    pub right: Option<HandData>,
}
