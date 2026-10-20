'use strict';
// Pure-JS `sharp` stub for the Termux/Android port of LobeChat v1.
//
// Native sharp (libvips) ships no Android prebuild, so the real package
// cannot run on Termux. But src/server/services/generation/index.ts does a
// static `import sharp from 'sharp'`, which lands in the tRPC lambda
// route's module graph — with sharp pruned, EVERY tRPC call died with
// MODULE_NOT_FOUND and the API returned plain-text 500s.
//
// This stub satisfies the import and the call shapes LobeChat uses:
//   sharp(buf).metadata()          -> real format/width/height parsed from
//                                     PNG/JPEG/WebP/GIF headers in pure JS
//   sharp(buf).resize(w, h).webp() -> chainable no-ops
//              .toBuffer()         -> resolves with the ORIGINAL buffer
//                                     (thumbnail == original image; larger,
//                                     but functionally correct)
// Only AI image-generation thumbnails/covers are affected, and only in
// that they are no longer downscaled.

function readMetadata(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < 10) return { format: undefined };

  // PNG: signature + IHDR width/height (BE uint32 at 16/20)
  if (buf[0] === 0x89 && buf[1] === 0x50 && buf[2] === 0x4e && buf[3] === 0x47) {
    if (buf.length >= 24) {
      return { format: 'png', height: buf.readUInt32BE(20), width: buf.readUInt32BE(16) };
    }
    return { format: 'png' };
  }

  // GIF: logical screen size (LE uint16 at 6/8)
  if (buf.toString('ascii', 0, 3) === 'GIF') {
    return { format: 'gif', height: buf.readUInt16LE(8), width: buf.readUInt16LE(6) };
  }

  // WebP: RIFF....WEBP + VP8 / VP8L / VP8X chunk
  if (buf.toString('ascii', 0, 4) === 'RIFF' && buf.toString('ascii', 8, 12) === 'WEBP') {
    const chunk = buf.toString('ascii', 12, 16);
    try {
      if (chunk === 'VP8 ' && buf.length >= 30) {
        return {
          format: 'webp',
          height: buf.readUInt16LE(28) & 0x3fff,
          width: buf.readUInt16LE(26) & 0x3fff,
        };
      }
      if (chunk === 'VP8L' && buf.length >= 25) {
        const b = buf.readUInt32LE(21);
        return { format: 'webp', height: ((b >> 14) & 0x3fff) + 1, width: (b & 0x3fff) + 1 };
      }
      if (chunk === 'VP8X' && buf.length >= 30) {
        return {
          format: 'webp',
          height: (buf[27] | (buf[28] << 8) | (buf[29] << 16)) + 1,
          width: (buf[24] | (buf[25] << 8) | (buf[26] << 16)) + 1,
        };
      }
    } catch {
      /* fall through to format-only */
    }
    return { format: 'webp' };
  }

  // JPEG: scan segments for a Start-Of-Frame marker
  if (buf[0] === 0xff && buf[1] === 0xd8) {
    let off = 2;
    while (off < buf.length - 9) {
      if (buf[off] !== 0xff) {
        off++;
        continue;
      }
      const marker = buf[off + 1];
      const isSOF =
        marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc;
      if (isSOF) {
        return {
          format: 'jpeg',
          height: buf.readUInt16BE(off + 5),
          width: buf.readUInt16BE(off + 7),
        };
      }
      const len = buf.readUInt16BE(off + 2);
      if (len < 2) break;
      off += 2 + len;
    }
    return { format: 'jpeg' };
  }

  return { format: undefined };
}

function sharp(input) {
  const buf = Buffer.isBuffer(input) ? input : Buffer.alloc(0);
  const chain = {
    jpeg: () => chain,
    metadata: async () => readMetadata(buf),
    png: () => chain,
    resize: () => chain,
    rotate: () => chain,
    toBuffer: async () => buf,
    toFile: async () => {
      throw new Error('sharp stub (Termux): toFile is not supported');
    },
    webp: () => chain,
  };
  return chain;
}

sharp.cache = () => true;
sharp.concurrency = () => 1;
sharp.counters = () => ({ process: 0, queue: 0 });
sharp.simd = () => false;

module.exports = sharp;
module.exports.default = sharp;
