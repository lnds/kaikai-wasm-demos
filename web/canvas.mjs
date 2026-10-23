// Pixel buffers for the canvas demos. kaikai writes packed 0xRRGGBB colours
// into an ImageData and draws it; extern "js" passes scalars and handles, not
// byte buffers, so the writes go one pixel per call.
let scratch = null;

export const pixels = {
  image: (w, h) => new ImageData(w, h),
  set(img, i, rgb) {
    const d = img.data;
    const o = i * 4;
    d[o] = (rgb >> 16) & 255;
    d[o + 1] = (rgb >> 8) & 255;
    d[o + 2] = rgb & 255;
    d[o + 3] = 255;
  },
  // Draws the whole image stretched over the canvas; `smooth` picks bilinear
  // filtering over crisp pixels.
  show(ctx, img, smooth) {
    if (!scratch) scratch = new OffscreenCanvas(img.width, img.height);
    if (scratch.width !== img.width || scratch.height !== img.height) {
      scratch.width = img.width;
      scratch.height = img.height;
    }
    scratch.getContext("2d").putImageData(img, 0, 0);
    ctx.imageSmoothingEnabled = smooth;
    ctx.drawImage(scratch, 0, 0, ctx.canvas.width, ctx.canvas.height);
  },
};
