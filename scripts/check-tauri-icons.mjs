import { readFileSync, statSync } from "node:fs";
import { inflateSync } from "node:zlib";

const pngs = [
  { path: "apps/desktop/src-tauri/icons/32x32.png", width: 32, height: 32 },
  { path: "apps/desktop/src-tauri/icons/128x128.png", width: 128, height: 128 },
  { path: "apps/desktop/src-tauri/icons/128x128@2x.png", width: 256, height: 256 },
  { path: "apps/desktop/src-tauri/icons/icon.png", width: 512, height: 512 },
];

const expectedBundleIcons = [
  "icons/32x32.png",
  "icons/128x128.png",
  "icons/128x128@2x.png",
  "icons/icon.icns",
  "icons/icon.ico",
];

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertPngDecodes({ path, width, height }) {
  const bytes = readFileSync(path);
  const signature = "89504e470d0a1a0a";
  assert(bytes.subarray(0, 8).toString("hex") === signature, `${path}: invalid PNG signature`);

  let offset = 8;
  const idat = [];
  let seenIhdr = false;
  let seenIend = false;

  while (offset < bytes.length) {
    assert(offset + 12 <= bytes.length, `${path}: truncated PNG chunk header`);
    const length = bytes.readUInt32BE(offset);
    const kind = bytes.subarray(offset + 4, offset + 8).toString("ascii");
    const dataStart = offset + 8;
    const dataEnd = dataStart + length;
    const crcEnd = dataEnd + 4;
    assert(crcEnd <= bytes.length, `${path}: truncated ${kind} chunk`);

    const data = bytes.subarray(dataStart, dataEnd);
    if (kind === "IHDR") {
      seenIhdr = true;
      assert(data.readUInt32BE(0) === width, `${path}: expected width ${width}`);
      assert(data.readUInt32BE(4) === height, `${path}: expected height ${height}`);
      assert(data[8] === 8, `${path}: expected 8-bit PNG`);
      assert(data[9] === 6, `${path}: expected RGBA PNG`);
      assert(data[10] === 0, `${path}: unsupported compression method`);
      assert(data[11] === 0, `${path}: unsupported filter method`);
      assert(data[12] === 0, `${path}: interlaced PNGs are not allowed here`);
    } else if (kind === "IDAT") {
      idat.push(data);
    } else if (kind === "IEND") {
      seenIend = true;
      break;
    }

    offset = crcEnd;
  }

  assert(seenIhdr, `${path}: missing IHDR`);
  assert(seenIend, `${path}: missing IEND`);
  assert(idat.length > 0, `${path}: missing IDAT`);

  const inflated = inflateSync(Buffer.concat(idat));
  const expectedBytes = height * (1 + width * 4);
  assert(
    inflated.length === expectedBytes,
    `${path}: inflated ${inflated.length} bytes, expected ${expectedBytes}`,
  );
}

function assertMagic(path, magic, label) {
  const bytes = readFileSync(path);
  assert(bytes.length > magic.length, `${path}: ${label} is empty`);
  assert(bytes.subarray(0, magic.length).equals(Buffer.from(magic)), `${path}: invalid ${label} magic`);
}

for (const png of pngs) {
  assertPngDecodes(png);
}

assertMagic("apps/desktop/src-tauri/icons/icon.icns", [0x69, 0x63, 0x6e, 0x73], "ICNS");
assertMagic("apps/desktop/src-tauri/icons/icon.ico", [0x00, 0x00, 0x01, 0x00], "ICO");
assert(statSync("apps/desktop/src-tauri/icons/app-icon.svg").size > 0, "source SVG is empty");

const config = JSON.parse(readFileSync("apps/desktop/src-tauri/tauri.conf.json", "utf8"));
assert(
  JSON.stringify(config.bundle?.icon) === JSON.stringify(expectedBundleIcons),
  "tauri.conf.json must reference the generated desktop icon set in order",
);

console.log("tauri icons: desktop icon set decodes and matches bundle config");
