"use strict";
(() => {
  var __create = Object.create;
  var __defProp = Object.defineProperty;
  var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
  var __getOwnPropNames = Object.getOwnPropertyNames;
  var __getProtoOf = Object.getPrototypeOf;
  var __hasOwnProp = Object.prototype.hasOwnProperty;
  var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
  var __commonJS = (cb, mod) => function __require() {
    return mod || (0, cb[__getOwnPropNames(cb)[0]])((mod = { exports: {} }).exports, mod), mod.exports;
  };
  var __export = (target, all) => {
    for (var name in all)
      __defProp(target, name, { get: all[name], enumerable: true });
  };
  var __copyProps = (to3, from, except, desc) => {
    if (from && typeof from === "object" || typeof from === "function") {
      for (let key of __getOwnPropNames(from))
        if (!__hasOwnProp.call(to3, key) && key !== except)
          __defProp(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
    }
    return to3;
  };
  var __toESM = (mod, isNodeMode, target) => (target = mod != null ? __create(__getProtoOf(mod)) : {}, __copyProps(
    // If the importer is in node compatibility mode or this is not an ESM
    // file that has been converted to a CommonJS file using a Babel-
    // compatible transform (i.e. "__esModule" has not been set), then set
    // "default" to the CommonJS "module.exports" for node compatibility.
    isNodeMode || !mod || !mod.__esModule ? __defProp(target, "default", { value: mod, enumerable: true }) : target,
    mod
  ));
  var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-distance/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-distance/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" && !isNaN(pitch2.step) && !isNaN(pitch2.alt) ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-distance/node_modules/@tonaljs/pitch-interval/dist/index.js
  var require_dist2 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-distance/node_modules/@tonaljs/pitch-interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_interval_exports = {};
      __export2(pitch_interval_exports, {
        coordToInterval: () => coordToInterval,
        interval: () => interval,
        tokenizeInterval: () => tokenizeInterval
      });
      module.exports = __toCommonJS(pitch_interval_exports);
      var import_pitch = require_dist();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoInterval = Object.freeze({
        empty: true,
        name: "",
        num: NaN,
        q: "",
        type: "",
        step: NaN,
        alt: NaN,
        dir: NaN,
        simple: NaN,
        semitones: NaN,
        chroma: NaN,
        coord: [],
        oct: NaN
      });
      var INTERVAL_TONAL_REGEX = "([-+]?\\d+)(d{1,4}|m|M|P|A{1,4})";
      var INTERVAL_SHORTHAND_REGEX = "(AA|A|P|M|m|d|dd)([-+]?\\d+)";
      var REGEX = new RegExp(
        "^" + INTERVAL_TONAL_REGEX + "|" + INTERVAL_SHORTHAND_REGEX + "$"
      );
      function tokenizeInterval(str) {
        const m3 = REGEX.exec(`${str}`);
        if (m3 === null) {
          return ["", ""];
        }
        return m3[1] ? [m3[1], m3[2]] : [m3[4], m3[3]];
      }
      var cache = {};
      function interval(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : (0, import_pitch.isPitch)(src) ? interval(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? interval(src.name) : NoInterval;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var TYPES = "PMMPPMM";
      function parse2(str) {
        const tokens = tokenizeInterval(str);
        if (tokens[0] === "") {
          return NoInterval;
        }
        const num = +tokens[0];
        const q6 = tokens[1];
        const step = (Math.abs(num) - 1) % 7;
        const t = TYPES[step];
        if (t === "M" && q6 === "P") {
          return NoInterval;
        }
        const type = t === "M" ? "majorable" : "perfectable";
        const name = "" + num + q6;
        const dir = num < 0 ? -1 : 1;
        const simple = num === 8 || num === -8 ? num : dir * (step + 1);
        const alt = qToAlt(type, q6);
        const oct = Math.floor((Math.abs(num) - 1) / 7);
        const semitones = dir * (SIZES[step] + alt + 12 * oct);
        const chroma = (dir * (SIZES[step] + alt) % 12 + 12) % 12;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct, dir });
        return {
          empty: false,
          name,
          num,
          q: q6,
          step,
          alt,
          dir,
          type,
          simple,
          semitones,
          chroma,
          coord,
          oct
        };
      }
      function coordToInterval(coord, forceDescending) {
        const [f4, o = 0] = coord;
        const isDescending = f4 * 7 + o * 12 < 0;
        const ivl = forceDescending || isDescending ? [-f4, -o, -1] : [f4, o, 1];
        return interval((0, import_pitch.pitch)(ivl));
      }
      function qToAlt(type, q6) {
        return q6 === "M" && type === "majorable" || q6 === "P" && type === "perfectable" ? 0 : q6 === "m" && type === "majorable" ? -1 : /^A+$/.test(q6) ? q6.length : /^d+$/.test(q6) ? -1 * (type === "perfectable" ? q6.length : q6.length + 1) : 0;
      }
      function pitchName(props) {
        const { step, alt, oct = 0, dir } = props;
        if (!dir) {
          return "";
        }
        const calcNum = step + 1 + 7 * oct;
        const num = calcNum === 0 ? step + 1 : calcNum;
        const d2 = dir < 0 ? "-" : "";
        const type = TYPES[step] === "M" ? "majorable" : "perfectable";
        const name = d2 + num + altToQ(type, alt);
        return name;
      }
      function altToQ(type, alt) {
        if (alt === 0) {
          return type === "majorable" ? "M" : "P";
        } else if (alt === -1 && type === "majorable") {
          return "m";
        } else if (alt > 0) {
          return fillStr("A", alt);
        } else {
          return fillStr("d", type === "perfectable" ? alt : alt + 1);
        }
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-note/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist3 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-note/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" && !isNaN(pitch2.step) && !isNaN(pitch2.alt) ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-note/dist/index.js
  var require_dist4 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-note/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod2) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod2);
      var pitch_note_exports = {};
      __export2(pitch_note_exports, {
        accToAlt: () => accToAlt,
        altToAcc: () => altToAcc,
        coordToNote: () => coordToNote,
        note: () => note,
        stepToLetter: () => stepToLetter,
        tokenizeNote: () => tokenizeNote
      });
      module.exports = __toCommonJS(pitch_note_exports);
      var import_pitch = require_dist3();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoNote = Object.freeze({
        empty: true,
        name: "",
        letter: "",
        acc: "",
        pc: "",
        step: NaN,
        alt: NaN,
        chroma: NaN,
        height: NaN,
        coord: [],
        midi: null,
        freq: null
      });
      var cache = /* @__PURE__ */ new Map();
      var stepToLetter = (step) => "CDEFGAB".charAt(step);
      var altToAcc = (alt) => alt < 0 ? fillStr("b", -alt) : fillStr("#", alt);
      var accToAlt = (acc) => acc[0] === "b" ? -acc.length : acc.length;
      function note(src) {
        const stringSrc = JSON.stringify(src);
        const cached = cache.get(stringSrc);
        if (cached) {
          return cached;
        }
        const value = typeof src === "string" ? parse2(src) : (0, import_pitch.isPitch)(src) ? note(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? note(src.name) : NoNote;
        cache.set(stringSrc, value);
        return value;
      }
      var REGEX = /^([a-gA-G]?)(#{1,}|b{1,}|x{1,}|)(-?\d*)\s*(.*)$/;
      function tokenizeNote(str) {
        const m3 = REGEX.exec(str);
        return m3 ? [m3[1].toUpperCase(), m3[2].replace(/x/g, "##"), m3[3], m3[4]] : ["", "", "", ""];
      }
      function coordToNote(noteCoord) {
        return note((0, import_pitch.pitch)(noteCoord));
      }
      var mod = (n2, m3) => (n2 % m3 + m3) % m3;
      var SEMI = [0, 2, 4, 5, 7, 9, 11];
      function parse2(noteName) {
        const tokens = tokenizeNote(noteName);
        if (tokens[0] === "" || tokens[3] !== "") {
          return NoNote;
        }
        const letter = tokens[0];
        const acc = tokens[1];
        const octStr = tokens[2];
        const step = (letter.charCodeAt(0) + 3) % 7;
        const alt = accToAlt(acc);
        const oct = octStr.length ? +octStr : void 0;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct });
        const name = letter + acc + octStr;
        const pc3 = letter + acc;
        const chroma = (SEMI[step] + alt + 120) % 12;
        const height = oct === void 0 ? mod(SEMI[step] + alt, 12) - 12 * 99 : SEMI[step] + alt + 12 * (oct + 1);
        const midi2 = height >= 0 && height <= 127 ? height : null;
        const freq = oct === void 0 ? null : Math.pow(2, (height - 69) / 12) * 440;
        return {
          empty: false,
          acc,
          alt,
          chroma,
          coord,
          freq,
          height,
          letter,
          midi: midi2,
          name,
          oct,
          pc: pc3,
          step
        };
      }
      function pitchName(props) {
        const { step, alt, oct } = props;
        const letter = stepToLetter(step);
        if (!letter) {
          return "";
        }
        const pc3 = letter + altToAcc(alt);
        return oct || oct === 0 ? pc3 + oct : pc3;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-distance/dist/index.js
  var require_dist5 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-distance/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_distance_exports = {};
      __export2(pitch_distance_exports, {
        distance: () => distance,
        tonicIntervalsTransposer: () => tonicIntervalsTransposer,
        transpose: () => transpose
      });
      module.exports = __toCommonJS(pitch_distance_exports);
      var import_pitch_interval = require_dist2();
      var import_pitch_note = require_dist4();
      function transpose(noteName, intervalName) {
        const note = (0, import_pitch_note.note)(noteName);
        const intervalCoord = Array.isArray(intervalName) ? intervalName : (0, import_pitch_interval.interval)(intervalName).coord;
        if (note.empty || !intervalCoord || intervalCoord.length < 2) {
          return "";
        }
        const noteCoord = note.coord;
        const tr2 = noteCoord.length === 1 ? [noteCoord[0] + intervalCoord[0]] : [noteCoord[0] + intervalCoord[0], noteCoord[1] + intervalCoord[1]];
        return (0, import_pitch_note.coordToNote)(tr2).name;
      }
      function tonicIntervalsTransposer(intervals, tonic) {
        const len = intervals.length;
        return (normalized) => {
          if (!tonic) return "";
          const index = normalized < 0 ? (len - -normalized % len) % len : normalized % len;
          const octaves = Math.floor(normalized / len);
          const root = transpose(tonic, [0, octaves]);
          return transpose(root, intervals[index]);
        };
      }
      function distance(fromNote, toNote) {
        const from = (0, import_pitch_note.note)(fromNote);
        const to3 = (0, import_pitch_note.note)(toNote);
        if (from.empty || to3.empty) {
          return "";
        }
        const fcoord = from.coord;
        const tcoord = to3.coord;
        const fifths = tcoord[0] - fcoord[0];
        const octs = fcoord.length === 2 && tcoord.length === 2 ? tcoord[1] - fcoord[1] : -Math.floor(fifths * 7 / 12);
        const forceDescending = to3.height === from.height && to3.midi !== null && from.oct === to3.oct && from.step > to3.step;
        return (0, import_pitch_interval.coordToInterval)([fifths, octs], forceDescending).name;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/abc-notation/dist/index.js
  var require_dist6 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/abc-notation/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var abc_notation_exports = {};
      __export2(abc_notation_exports, {
        abcToScientificNotation: () => abcToScientificNotation,
        default: () => abc_notation_default,
        distance: () => distance,
        scientificToAbcNotation: () => scientificToAbcNotation,
        tokenize: () => tokenize,
        transpose: () => transpose
      });
      module.exports = __toCommonJS(abc_notation_exports);
      var import_pitch_distance = require_dist5();
      var import_pitch_note = require_dist4();
      var fillStr = (character, times) => Array(times + 1).join(character);
      var REGEX = /^(_{1,}|=|\^{1,}|)([abcdefgABCDEFG])([,']*)$/;
      function tokenize(str) {
        const m3 = REGEX.exec(str);
        if (!m3) {
          return ["", "", ""];
        }
        return [m3[1], m3[2], m3[3]];
      }
      function abcToScientificNotation(str) {
        const [acc, letter, oct] = tokenize(str);
        if (letter === "") {
          return "";
        }
        let o = 4;
        for (let i = 0; i < oct.length; i++) {
          o += oct.charAt(i) === "," ? -1 : 1;
        }
        const a2 = acc[0] === "_" ? acc.replace(/_/g, "b") : acc[0] === "^" ? acc.replace(/\^/g, "#") : "";
        return letter.charCodeAt(0) > 96 ? letter.toUpperCase() + a2 + (o + 1) : letter + a2 + o;
      }
      function scientificToAbcNotation(str) {
        const n2 = (0, import_pitch_note.note)(str);
        if (n2.empty || !n2.oct && n2.oct !== 0) {
          return "";
        }
        const { letter, acc, oct } = n2;
        const a2 = acc[0] === "b" ? acc.replace(/b/g, "_") : acc.replace(/#/g, "^");
        const l2 = oct > 4 ? letter.toLowerCase() : letter;
        const o = oct === 5 ? "" : oct > 4 ? fillStr("'", oct - 5) : fillStr(",", 4 - oct);
        return a2 + l2 + o;
      }
      function transpose(note2, interval) {
        return scientificToAbcNotation((0, import_pitch_distance.transpose)(abcToScientificNotation(note2), interval));
      }
      function distance(from, to3) {
        return (0, import_pitch_distance.distance)(abcToScientificNotation(from), abcToScientificNotation(to3));
      }
      var abc_notation_default = {
        abcToScientificNotation,
        scientificToAbcNotation,
        tokenize,
        transpose,
        distance
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/array/dist/index.js
  var require_dist7 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/array/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var array_exports = {};
      __export2(array_exports, {
        compact: () => compact,
        permutations: () => permutations,
        range: () => range,
        rotate: () => rotate,
        shuffle: () => shuffle,
        sortedNoteNames: () => sortedNoteNames,
        sortedUniqNoteNames: () => sortedUniqNoteNames
      });
      module.exports = __toCommonJS(array_exports);
      var import_pitch_note = require_dist4();
      function ascR(b2, n2) {
        const a2 = [];
        for (; n2--; a2[n2] = n2 + b2) ;
        return a2;
      }
      function descR(b2, n2) {
        const a2 = [];
        for (; n2--; a2[n2] = b2 - n2) ;
        return a2;
      }
      function range(from, to3) {
        return from < to3 ? ascR(from, to3 - from + 1) : descR(from, from - to3 + 1);
      }
      function rotate(times, arr) {
        const len = arr.length;
        const n2 = (times % len + len) % len;
        return arr.slice(n2, len).concat(arr.slice(0, n2));
      }
      function compact(arr) {
        return arr.filter((n2) => n2 === 0 || n2);
      }
      function sortedNoteNames(notes) {
        const valid = notes.map((n2) => (0, import_pitch_note.note)(n2)).filter((n2) => !n2.empty);
        return valid.sort((a2, b2) => a2.height - b2.height).map((n2) => n2.name);
      }
      function sortedUniqNoteNames(arr) {
        return sortedNoteNames(arr).filter((n2, i, a2) => i === 0 || n2 !== a2[i - 1]);
      }
      function shuffle(arr, rnd = Math.random) {
        let i;
        let t;
        let m3 = arr.length;
        while (m3) {
          i = Math.floor(rnd() * m3--);
          t = arr[m3];
          arr[m3] = arr[i];
          arr[i] = t;
        }
        return arr;
      }
      function permutations(arr) {
        if (arr.length === 0) {
          return [[]];
        }
        return permutations(arr.slice(1)).reduce((acc, perm) => {
          return acc.concat(
            arr.map((e, pos) => {
              const newPerm = perm.slice();
              newPerm.splice(pos, 0, arr[0]);
              return newPerm;
            })
          );
        }, []);
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/collection/dist/index.js
  var require_dist8 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/collection/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var collection_exports = {};
      __export2(collection_exports, {
        compact: () => compact,
        default: () => collection_default,
        permutations: () => permutations,
        range: () => range,
        rotate: () => rotate,
        shuffle: () => shuffle
      });
      module.exports = __toCommonJS(collection_exports);
      function ascR(b2, n2) {
        const a2 = [];
        for (; n2--; a2[n2] = n2 + b2) ;
        return a2;
      }
      function descR(b2, n2) {
        const a2 = [];
        for (; n2--; a2[n2] = b2 - n2) ;
        return a2;
      }
      function range(from, to3) {
        return from < to3 ? ascR(from, to3 - from + 1) : descR(from, from - to3 + 1);
      }
      function rotate(times, arr) {
        const len = arr.length;
        const n2 = (times % len + len) % len;
        return arr.slice(n2, len).concat(arr.slice(0, n2));
      }
      function compact(arr) {
        return arr.filter((n2) => n2 === 0 || n2);
      }
      function shuffle(arr, rnd = Math.random) {
        let i;
        let t;
        let m3 = arr.length;
        while (m3) {
          i = Math.floor(rnd() * m3--);
          t = arr[m3];
          arr[m3] = arr[i];
          arr[i] = t;
        }
        return arr;
      }
      function permutations(arr) {
        if (arr.length === 0) {
          return [[]];
        }
        return permutations(arr.slice(1)).reduce((acc, perm) => {
          return acc.concat(
            arr.map((e, pos) => {
              const newPerm = perm.slice();
              newPerm.splice(pos, 0, arr[0]);
              return newPerm;
            })
          );
        }, []);
      }
      var collection_default = {
        compact,
        permutations,
        range,
        rotate,
        shuffle
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pcset/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist9 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pcset/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" && !isNaN(pitch2.step) && !isNaN(pitch2.alt) ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pcset/node_modules/@tonaljs/pitch-interval/dist/index.js
  var require_dist10 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pcset/node_modules/@tonaljs/pitch-interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_interval_exports = {};
      __export2(pitch_interval_exports, {
        coordToInterval: () => coordToInterval,
        interval: () => interval,
        tokenizeInterval: () => tokenizeInterval
      });
      module.exports = __toCommonJS(pitch_interval_exports);
      var import_pitch = require_dist9();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoInterval = Object.freeze({
        empty: true,
        name: "",
        num: NaN,
        q: "",
        type: "",
        step: NaN,
        alt: NaN,
        dir: NaN,
        simple: NaN,
        semitones: NaN,
        chroma: NaN,
        coord: [],
        oct: NaN
      });
      var INTERVAL_TONAL_REGEX = "([-+]?\\d+)(d{1,4}|m|M|P|A{1,4})";
      var INTERVAL_SHORTHAND_REGEX = "(AA|A|P|M|m|d|dd)([-+]?\\d+)";
      var REGEX = new RegExp(
        "^" + INTERVAL_TONAL_REGEX + "|" + INTERVAL_SHORTHAND_REGEX + "$"
      );
      function tokenizeInterval(str) {
        const m3 = REGEX.exec(`${str}`);
        if (m3 === null) {
          return ["", ""];
        }
        return m3[1] ? [m3[1], m3[2]] : [m3[4], m3[3]];
      }
      var cache = {};
      function interval(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : (0, import_pitch.isPitch)(src) ? interval(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? interval(src.name) : NoInterval;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var TYPES = "PMMPPMM";
      function parse2(str) {
        const tokens = tokenizeInterval(str);
        if (tokens[0] === "") {
          return NoInterval;
        }
        const num = +tokens[0];
        const q6 = tokens[1];
        const step = (Math.abs(num) - 1) % 7;
        const t = TYPES[step];
        if (t === "M" && q6 === "P") {
          return NoInterval;
        }
        const type = t === "M" ? "majorable" : "perfectable";
        const name = "" + num + q6;
        const dir = num < 0 ? -1 : 1;
        const simple = num === 8 || num === -8 ? num : dir * (step + 1);
        const alt = qToAlt(type, q6);
        const oct = Math.floor((Math.abs(num) - 1) / 7);
        const semitones = dir * (SIZES[step] + alt + 12 * oct);
        const chroma = (dir * (SIZES[step] + alt) % 12 + 12) % 12;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct, dir });
        return {
          empty: false,
          name,
          num,
          q: q6,
          step,
          alt,
          dir,
          type,
          simple,
          semitones,
          chroma,
          coord,
          oct
        };
      }
      function coordToInterval(coord, forceDescending) {
        const [f4, o = 0] = coord;
        const isDescending = f4 * 7 + o * 12 < 0;
        const ivl = forceDescending || isDescending ? [-f4, -o, -1] : [f4, o, 1];
        return interval((0, import_pitch.pitch)(ivl));
      }
      function qToAlt(type, q6) {
        return q6 === "M" && type === "majorable" || q6 === "P" && type === "perfectable" ? 0 : q6 === "m" && type === "majorable" ? -1 : /^A+$/.test(q6) ? q6.length : /^d+$/.test(q6) ? -1 * (type === "perfectable" ? q6.length : q6.length + 1) : 0;
      }
      function pitchName(props) {
        const { step, alt, oct = 0, dir } = props;
        if (!dir) {
          return "";
        }
        const calcNum = step + 1 + 7 * oct;
        const num = calcNum === 0 ? step + 1 : calcNum;
        const d2 = dir < 0 ? "-" : "";
        const type = TYPES[step] === "M" ? "majorable" : "perfectable";
        const name = d2 + num + altToQ(type, alt);
        return name;
      }
      function altToQ(type, alt) {
        if (alt === 0) {
          return type === "majorable" ? "M" : "P";
        } else if (alt === -1 && type === "majorable") {
          return "m";
        } else if (alt > 0) {
          return fillStr("A", alt);
        } else {
          return fillStr("d", type === "perfectable" ? alt : alt + 1);
        }
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pcset/dist/index.js
  var require_dist11 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pcset/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pcset_exports = {};
      __export2(pcset_exports, {
        EmptyPcset: () => EmptyPcset,
        chroma: () => chroma,
        chromas: () => chromas,
        default: () => pcset_default,
        filter: () => filter,
        get: () => get,
        includes: () => includes,
        intervals: () => intervals,
        isChroma: () => isChroma,
        isEqual: () => isEqual,
        isNoteIncludedIn: () => isNoteIncludedIn,
        isSubsetOf: () => isSubsetOf,
        isSupersetOf: () => isSupersetOf,
        modes: () => modes,
        notes: () => notes,
        num: () => num,
        pcset: () => pcset
      });
      module.exports = __toCommonJS(pcset_exports);
      var import_collection = require_dist8();
      var import_pitch_distance = require_dist5();
      var import_pitch_interval = require_dist10();
      var import_pitch_note = require_dist4();
      var EmptyPcset = {
        empty: true,
        name: "",
        setNum: 0,
        chroma: "000000000000",
        normalized: "000000000000",
        intervals: []
      };
      var setNumToChroma = (num2) => Number(num2).toString(2).padStart(12, "0");
      var chromaToNumber = (chroma2) => parseInt(chroma2, 2);
      var REGEX = /^[01]{12}$/;
      function isChroma(set) {
        return REGEX.test(set);
      }
      var isPcsetNum = (set) => typeof set === "number" && set >= 0 && set <= 4095;
      var isPcset = (set) => set && isChroma(set.chroma);
      var cache = { [EmptyPcset.chroma]: EmptyPcset };
      function get(src) {
        const chroma2 = isChroma(src) ? src : isPcsetNum(src) ? setNumToChroma(src) : Array.isArray(src) ? listToChroma(src) : isPcset(src) ? src.chroma : EmptyPcset.chroma;
        return cache[chroma2] = cache[chroma2] || chromaToPcset(chroma2);
      }
      var pcset = get;
      var chroma = (set) => get(set).chroma;
      var intervals = (set) => get(set).intervals;
      var num = (set) => get(set).setNum;
      var IVLS = [
        "1P",
        "2m",
        "2M",
        "3m",
        "3M",
        "4P",
        "5d",
        "5P",
        "6m",
        "6M",
        "7m",
        "7M"
      ];
      function chromaToIntervals(chroma2) {
        const intervals2 = [];
        for (let i = 0; i < 12; i++) {
          if (chroma2.charAt(i) === "1") intervals2.push(IVLS[i]);
        }
        return intervals2;
      }
      function notes(set) {
        return get(set).intervals.map((ivl) => (0, import_pitch_distance.transpose)("C", ivl));
      }
      function chromas() {
        return (0, import_collection.range)(2048, 4095).map(setNumToChroma);
      }
      function modes(set, normalize = true) {
        const pcs = get(set);
        const binary = pcs.chroma.split("");
        return (0, import_collection.compact)(
          binary.map((_5, i) => {
            const r = (0, import_collection.rotate)(i, binary);
            return normalize && r[0] === "0" ? null : r.join("");
          })
        );
      }
      function isEqual(s12, s2) {
        return get(s12).setNum === get(s2).setNum;
      }
      function isSubsetOf(set) {
        const s2 = get(set).setNum;
        return (notes2) => {
          const o = get(notes2).setNum;
          return s2 && s2 !== o && (o & s2) === o;
        };
      }
      function isSupersetOf(set) {
        const s2 = get(set).setNum;
        return (notes2) => {
          const o = get(notes2).setNum;
          return s2 && s2 !== o && (o | s2) === o;
        };
      }
      function isNoteIncludedIn(set) {
        const s2 = get(set);
        return (noteName) => {
          const n2 = (0, import_pitch_note.note)(noteName);
          return s2 && !n2.empty && s2.chroma.charAt(n2.chroma) === "1";
        };
      }
      var includes = isNoteIncludedIn;
      function filter(set) {
        const isIncluded = isNoteIncludedIn(set);
        return (notes2) => {
          return notes2.filter(isIncluded);
        };
      }
      var pcset_default = {
        get,
        chroma,
        num,
        intervals,
        chromas,
        isSupersetOf,
        isSubsetOf,
        isNoteIncludedIn,
        isEqual,
        filter,
        modes,
        notes,
        // deprecated
        pcset
      };
      function chromaRotations(chroma2) {
        const binary = chroma2.split("");
        return binary.map((_5, i) => (0, import_collection.rotate)(i, binary).join(""));
      }
      function chromaToPcset(chroma2) {
        const setNum = chromaToNumber(chroma2);
        const normalizedNum = chromaRotations(chroma2).map(chromaToNumber).filter((n2) => n2 >= 2048).sort()[0];
        const normalized = setNumToChroma(normalizedNum);
        const intervals2 = chromaToIntervals(chroma2);
        return {
          empty: false,
          name: "",
          setNum,
          chroma: chroma2,
          normalized,
          intervals: intervals2
        };
      }
      function listToChroma(set) {
        if (set.length === 0) {
          return EmptyPcset.chroma;
        }
        let pitch;
        const binary = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        for (let i = 0; i < set.length; i++) {
          pitch = (0, import_pitch_note.note)(set[i]);
          if (pitch.empty) pitch = (0, import_pitch_interval.interval)(set[i]);
          if (!pitch.empty) binary[pitch.chroma] = 1;
        }
        return binary.join("");
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord-detect/node_modules/@tonaljs/chord-type/dist/index.js
  var require_dist12 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord-detect/node_modules/@tonaljs/chord-type/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var chord_type_exports = {};
      __export2(chord_type_exports, {
        add: () => add2,
        addAlias: () => addAlias,
        all: () => all,
        chordType: () => chordType,
        default: () => chord_type_default,
        entries: () => entries,
        get: () => get,
        keys: () => keys,
        names: () => names,
        removeAll: () => removeAll,
        symbols: () => symbols
      });
      module.exports = __toCommonJS(chord_type_exports);
      var import_pcset = require_dist11();
      var CHORDS = [
        // ==Major==
        ["1P 3M 5P", "major", "M ^  maj"],
        ["1P 3M 5P 7M", "major seventh", "maj7 \u0394 ma7 M7 Maj7 ^7"],
        ["1P 3M 5P 7M 9M", "major ninth", "maj9 \u03949 ^9"],
        ["1P 3M 5P 7M 9M 13M", "major thirteenth", "maj13 Maj13 ^13"],
        ["1P 3M 5P 6M", "sixth", "6 add6 add13 M6"],
        ["1P 3M 5P 6M 9M", "sixth added ninth", "6add9 6/9 69 M69"],
        ["1P 3M 6m 7M", "major seventh flat sixth", "M7b6 ^7b6"],
        [
          "1P 3M 5P 7M 11A",
          "major seventh sharp eleventh",
          "maj#4 \u0394#4 \u0394#11 M7#11 ^7#11 maj7#11"
        ],
        // ==Minor==
        // '''Normal'''
        ["1P 3m 5P", "minor", "m min -"],
        ["1P 3m 5P 7m", "minor seventh", "m7 min7 mi7 -7"],
        [
          "1P 3m 5P 7M",
          "minor/major seventh",
          "m/ma7 m/maj7 mM7 mMaj7 m/M7 -\u03947 m\u0394 -^7 -maj7"
        ],
        ["1P 3m 5P 6M", "minor sixth", "m6 -6"],
        ["1P 3m 5P 7m 9M", "minor ninth", "m9 -9"],
        ["1P 3m 5P 7M 9M", "minor/major ninth", "mM9 mMaj9 -^9"],
        ["1P 3m 5P 7m 9M 11P", "minor eleventh", "m11 -11"],
        ["1P 3m 5P 7m 9M 13M", "minor thirteenth", "m13 -13"],
        // '''Diminished'''
        ["1P 3m 5d", "diminished", "dim \xB0 o"],
        ["1P 3m 5d 7d", "diminished seventh", "dim7 \xB07 o7"],
        ["1P 3m 5d 7m", "half-diminished", "m7b5 \xF8 -7b5 h7 h"],
        // ==Dominant/Seventh==
        // '''Normal'''
        ["1P 3M 5P 7m", "dominant seventh", "7 dom"],
        ["1P 3M 5P 7m 9M", "dominant ninth", "9"],
        ["1P 3M 5P 7m 9M 13M", "dominant thirteenth", "13"],
        ["1P 3M 5P 7m 11A", "lydian dominant seventh", "7#11 7#4"],
        // '''Altered'''
        ["1P 3M 5P 7m 9m", "dominant flat ninth", "7b9"],
        ["1P 3M 5P 7m 9A", "dominant sharp ninth", "7#9"],
        ["1P 3M 7m 9m", "altered", "alt7"],
        // '''Suspended'''
        ["1P 4P 5P", "suspended fourth", "sus4 sus"],
        ["1P 2M 5P", "suspended second", "sus2"],
        ["1P 4P 5P 7m", "suspended fourth seventh", "7sus4 7sus"],
        ["1P 5P 7m 9M 11P", "eleventh", "11"],
        [
          "1P 4P 5P 7m 9m",
          "suspended fourth flat ninth",
          "b9sus phryg 7b9sus 7b9sus4"
        ],
        // ==Other==
        ["1P 5P", "fifth", "5"],
        ["1P 3M 5A", "augmented", "aug + +5 ^#5"],
        ["1P 3m 5A", "minor augmented", "m#5 -#5 m+"],
        ["1P 3M 5A 7M", "augmented seventh", "maj7#5 maj7+5 +maj7 ^7#5"],
        [
          "1P 3M 5P 7M 9M 11A",
          "major sharp eleventh (lydian)",
          "maj9#11 \u03949#11 ^9#11"
        ],
        // ==Legacy==
        ["1P 2M 4P 5P", "", "sus24 sus4add9"],
        ["1P 3M 5A 7M 9M", "", "maj9#5 Maj9#5"],
        ["1P 3M 5A 7m", "", "7#5 +7 7+ 7aug aug7"],
        ["1P 3M 5A 7m 9A", "", "7#5#9 7#9#5 7alt"],
        ["1P 3M 5A 7m 9M", "", "9#5 9+"],
        ["1P 3M 5A 7m 9M 11A", "", "9#5#11"],
        ["1P 3M 5A 7m 9m", "", "7#5b9 7b9#5"],
        ["1P 3M 5A 7m 9m 11A", "", "7#5b9#11"],
        ["1P 3M 5A 9A", "", "+add#9"],
        ["1P 3M 5A 9M", "", "M#5add9 +add9"],
        ["1P 3M 5P 6M 11A", "", "M6#11 M6b5 6#11 6b5"],
        ["1P 3M 5P 6M 7M 9M", "", "M7add13"],
        ["1P 3M 5P 6M 9M 11A", "", "69#11"],
        ["1P 3m 5P 6M 9M", "", "m69 -69"],
        ["1P 3M 5P 6m 7m", "", "7b6"],
        ["1P 3M 5P 7M 9A 11A", "", "maj7#9#11"],
        ["1P 3M 5P 7M 9M 11A 13M", "", "M13#11 maj13#11 M13+4 M13#4"],
        ["1P 3M 5P 7M 9m", "", "M7b9"],
        ["1P 3M 5P 7m 11A 13m", "", "7#11b13 7b5b13"],
        ["1P 3M 5P 7m 13M", "", "7add6 67 7add13"],
        ["1P 3M 5P 7m 9A 11A", "", "7#9#11 7b5#9 7#9b5"],
        ["1P 3M 5P 7m 9A 11A 13M", "", "13#9#11"],
        ["1P 3M 5P 7m 9A 11A 13m", "", "7#9#11b13"],
        ["1P 3M 5P 7m 9A 13M", "", "13#9"],
        ["1P 3M 5P 7m 9A 13m", "", "7#9b13"],
        ["1P 3M 5P 7m 9M 11A", "", "9#11 9+4 9#4"],
        ["1P 3M 5P 7m 9M 11A 13M", "", "13#11 13+4 13#4"],
        ["1P 3M 5P 7m 9M 11A 13m", "", "9#11b13 9b5b13"],
        ["1P 3M 5P 7m 9m 11A", "", "7b9#11 7b5b9 7b9b5"],
        ["1P 3M 5P 7m 9m 11A 13M", "", "13b9#11"],
        ["1P 3M 5P 7m 9m 11A 13m", "", "7b9b13#11 7b9#11b13 7b5b9b13"],
        ["1P 3M 5P 7m 9m 13M", "", "13b9"],
        ["1P 3M 5P 7m 9m 13m", "", "7b9b13"],
        ["1P 3M 5P 7m 9m 9A", "", "7b9#9"],
        ["1P 3M 5P 9M", "", "Madd9 2 add9 add2"],
        ["1P 3M 5P 9m", "", "Maddb9"],
        ["1P 3M 5d", "", "Mb5"],
        ["1P 3M 5d 6M 7m 9M", "", "13b5"],
        ["1P 3M 5d 7M", "", "M7b5"],
        ["1P 3M 5d 7M 9M", "", "M9b5"],
        ["1P 3M 5d 7m", "", "7b5"],
        ["1P 3M 5d 7m 9M", "", "9b5"],
        ["1P 3M 7m", "", "7no5"],
        ["1P 3M 7m 13m", "", "7b13"],
        ["1P 3M 7m 9M", "", "9no5"],
        ["1P 3M 7m 9M 13M", "", "13no5"],
        ["1P 3M 7m 9M 13m", "", "9b13"],
        ["1P 3m 4P 5P", "", "madd4"],
        ["1P 3m 5P 6m 7M", "", "mMaj7b6"],
        ["1P 3m 5P 6m 7M 9M", "", "mMaj9b6"],
        ["1P 3m 5P 7m 11P", "", "m7add11 m7add4"],
        ["1P 3m 5P 9M", "", "madd9"],
        ["1P 3m 5d 6M 7M", "", "o7M7"],
        ["1P 3m 5d 7M", "", "oM7"],
        ["1P 3m 6m 7M", "", "mb6M7"],
        ["1P 3m 6m 7m", "", "m7#5"],
        ["1P 3m 6m 7m 9M", "", "m9#5"],
        ["1P 3m 5A 7m 9M 11P", "", "m11A"],
        ["1P 3m 6m 9m", "", "mb6b9"],
        ["1P 2M 3m 5d 7m", "", "m9b5"],
        ["1P 4P 5A 7M", "", "M7#5sus4"],
        ["1P 4P 5A 7M 9M", "", "M9#5sus4"],
        ["1P 4P 5A 7m", "", "7#5sus4"],
        ["1P 4P 5P 7M", "", "M7sus4"],
        ["1P 4P 5P 7M 9M", "", "M9sus4"],
        ["1P 4P 5P 7m 9M", "", "9sus4 9sus"],
        ["1P 4P 5P 7m 9M 13M", "", "13sus4 13sus"],
        ["1P 4P 5P 7m 9m 13m", "", "7sus4b9b13 7b9b13sus4"],
        ["1P 4P 7m 10m", "", "4 quartal"],
        ["1P 5P 7m 9m 11P", "", "11b9"]
      ];
      var data_default = CHORDS;
      var NoChordType = {
        ...import_pcset.EmptyPcset,
        name: "",
        quality: "Unknown",
        intervals: [],
        aliases: []
      };
      var dictionary = [];
      var index = {};
      function get(type) {
        return index[type] || NoChordType;
      }
      var chordType = get;
      function names() {
        return dictionary.map((chord) => chord.name).filter((x2) => x2);
      }
      function symbols() {
        return dictionary.map((chord) => chord.aliases[0]).filter((x2) => x2);
      }
      function keys() {
        return Object.keys(index);
      }
      function all() {
        return dictionary.slice();
      }
      var entries = all;
      function removeAll() {
        dictionary = [];
        index = {};
      }
      function add2(intervals, aliases, fullName) {
        const quality = getQuality(intervals);
        const chord = {
          ...(0, import_pcset.get)(intervals),
          name: fullName || "",
          quality,
          intervals,
          aliases
        };
        dictionary.push(chord);
        if (chord.name) {
          index[chord.name] = chord;
        }
        index[chord.setNum] = chord;
        index[chord.chroma] = chord;
        chord.aliases.forEach((alias) => addAlias(chord, alias));
      }
      function addAlias(chord, alias) {
        index[alias] = chord;
      }
      function getQuality(intervals) {
        const has = (interval) => intervals.indexOf(interval) !== -1;
        return has("5A") ? "Augmented" : has("3M") ? "Major" : has("5d") ? "Diminished" : has("3m") ? "Minor" : "Unknown";
      }
      data_default.forEach(
        ([ivls, fullName, names2]) => add2(ivls.split(" "), names2.split(" "), fullName)
      );
      dictionary.sort((a2, b2) => a2.setNum - b2.setNum);
      var chord_type_default = {
        names,
        symbols,
        get,
        all,
        add: add2,
        removeAll,
        keys,
        // deprecated
        entries,
        chordType
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord-detect/dist/index.js
  var require_dist13 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord-detect/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var chord_detect_exports = {};
      __export2(chord_detect_exports, {
        default: () => chord_detect_default,
        detect: () => detect2
      });
      module.exports = __toCommonJS(chord_detect_exports);
      var import_chord_type = require_dist12();
      var import_pcset = require_dist11();
      var import_pitch_note = require_dist4();
      var namedSet = (notes) => {
        const pcToName = notes.reduce((record, n2) => {
          const chroma = (0, import_pitch_note.note)(n2).chroma;
          if (chroma !== void 0) {
            record[chroma] = record[chroma] || (0, import_pitch_note.note)(n2).name;
          }
          return record;
        }, {});
        return (chroma) => pcToName[chroma];
      };
      function detect2(source, options = {}) {
        const notes = source.map((n2) => (0, import_pitch_note.note)(n2).pc).filter((x2) => x2);
        if (import_pitch_note.note.length === 0) {
          return [];
        }
        const found = findMatches(notes, 1, options);
        return found.filter((chord) => chord.weight).sort((a2, b2) => b2.weight - a2.weight).map((chord) => chord.name);
      }
      var BITMASK = {
        // 3m 000100000000
        // 3M 000010000000
        anyThirds: 384,
        // 5P 000000010000
        perfectFifth: 16,
        // 5d 000000100000
        // 5A 000000001000
        nonPerfectFifths: 40,
        anySeventh: 3
      };
      var testChromaNumber = (bitmask) => (chromaNumber) => Boolean(chromaNumber & bitmask);
      var hasAnyThird = testChromaNumber(BITMASK.anyThirds);
      var hasPerfectFifth = testChromaNumber(BITMASK.perfectFifth);
      var hasAnySeventh = testChromaNumber(BITMASK.anySeventh);
      var hasNonPerfectFifth = testChromaNumber(BITMASK.nonPerfectFifths);
      function hasAnyThirdAndPerfectFifthAndAnySeventh(chordType) {
        const chromaNumber = parseInt(chordType.chroma, 2);
        return hasAnyThird(chromaNumber) && hasPerfectFifth(chromaNumber) && hasAnySeventh(chromaNumber);
      }
      function withPerfectFifth(chroma) {
        const chromaNumber = parseInt(chroma, 2);
        return hasNonPerfectFifth(chromaNumber) ? chroma : (chromaNumber | 16).toString(2);
      }
      function findMatches(notes, weight, options) {
        const tonic = notes[0];
        const tonicChroma = (0, import_pitch_note.note)(tonic).chroma;
        const noteName = namedSet(notes);
        const allModes = (0, import_pcset.modes)(notes, false);
        const found = [];
        allModes.forEach((mode, index) => {
          const modeWithPerfectFifth = options.assumePerfectFifth && withPerfectFifth(mode);
          const chordTypes = (0, import_chord_type.all)().filter((chordType) => {
            if (options.assumePerfectFifth && hasAnyThirdAndPerfectFifthAndAnySeventh(chordType)) {
              return chordType.chroma === modeWithPerfectFifth;
            }
            return chordType.chroma === mode;
          });
          chordTypes.forEach((chordType) => {
            const chordName = chordType.aliases[0];
            const baseNote = noteName(index);
            const isInversion = index !== tonicChroma;
            if (isInversion) {
              found.push({
                weight: 0.5 * weight,
                name: `${baseNote}${chordName}/${tonic}`
              });
            } else {
              found.push({ weight: 1 * weight, name: `${baseNote}${chordName}` });
            }
          });
        });
        return found;
      }
      var chord_detect_default = { detect: detect2 };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist14 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-interval/dist/index.js
  var require_dist15 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/pitch-interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_interval_exports = {};
      __export2(pitch_interval_exports, {
        coordToInterval: () => coordToInterval,
        interval: () => interval,
        tokenizeInterval: () => tokenizeInterval
      });
      module.exports = __toCommonJS(pitch_interval_exports);
      var import_pitch = require_dist14();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoInterval = { empty: true, name: "", acc: "" };
      var INTERVAL_TONAL_REGEX = "([-+]?\\d+)(d{1,4}|m|M|P|A{1,4})";
      var INTERVAL_SHORTHAND_REGEX = "(AA|A|P|M|m|d|dd)([-+]?\\d+)";
      var REGEX = new RegExp(
        "^" + INTERVAL_TONAL_REGEX + "|" + INTERVAL_SHORTHAND_REGEX + "$"
      );
      function tokenizeInterval(str) {
        const m3 = REGEX.exec(`${str}`);
        if (m3 === null) {
          return ["", ""];
        }
        return m3[1] ? [m3[1], m3[2]] : [m3[4], m3[3]];
      }
      var cache = {};
      function interval(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : (0, import_pitch.isPitch)(src) ? interval(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? interval(src.name) : NoInterval;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var TYPES = "PMMPPMM";
      function parse2(str) {
        const tokens = tokenizeInterval(str);
        if (tokens[0] === "") {
          return NoInterval;
        }
        const num = +tokens[0];
        const q6 = tokens[1];
        const step = (Math.abs(num) - 1) % 7;
        const t = TYPES[step];
        if (t === "M" && q6 === "P") {
          return NoInterval;
        }
        const type = t === "M" ? "majorable" : "perfectable";
        const name = "" + num + q6;
        const dir = num < 0 ? -1 : 1;
        const simple = num === 8 || num === -8 ? num : dir * (step + 1);
        const alt = qToAlt(type, q6);
        const oct = Math.floor((Math.abs(num) - 1) / 7);
        const semitones = dir * (SIZES[step] + alt + 12 * oct);
        const chroma = (dir * (SIZES[step] + alt) % 12 + 12) % 12;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct, dir });
        return {
          empty: false,
          name,
          num,
          q: q6,
          step,
          alt,
          dir,
          type,
          simple,
          semitones,
          chroma,
          coord,
          oct
        };
      }
      function coordToInterval(coord, forceDescending) {
        const [f4, o = 0] = coord;
        const isDescending = f4 * 7 + o * 12 < 0;
        const ivl = forceDescending || isDescending ? [-f4, -o, -1] : [f4, o, 1];
        return interval((0, import_pitch.pitch)(ivl));
      }
      function qToAlt(type, q6) {
        return q6 === "M" && type === "majorable" || q6 === "P" && type === "perfectable" ? 0 : q6 === "m" && type === "majorable" ? -1 : /^A+$/.test(q6) ? q6.length : /^d+$/.test(q6) ? -1 * (type === "perfectable" ? q6.length : q6.length + 1) : 0;
      }
      function pitchName(props) {
        const { step, alt, oct = 0, dir } = props;
        if (!dir) {
          return "";
        }
        const calcNum = step + 1 + 7 * oct;
        const num = calcNum === 0 ? step + 1 : calcNum;
        const d2 = dir < 0 ? "-" : "";
        const type = TYPES[step] === "M" ? "majorable" : "perfectable";
        const name = d2 + num + altToQ(type, alt);
        return name;
      }
      function altToQ(type, alt) {
        if (alt === 0) {
          return type === "majorable" ? "M" : "P";
        } else if (alt === -1 && type === "majorable") {
          return "m";
        } else if (alt > 0) {
          return fillStr("A", alt);
        } else {
          return fillStr("d", type === "perfectable" ? alt : alt + 1);
        }
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/core/node_modules/@tonaljs/pitch-note/dist/index.js
  var require_dist16 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/core/node_modules/@tonaljs/pitch-note/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod2) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod2);
      var pitch_note_exports = {};
      __export2(pitch_note_exports, {
        accToAlt: () => accToAlt,
        altToAcc: () => altToAcc,
        coordToNote: () => coordToNote,
        note: () => note,
        stepToLetter: () => stepToLetter,
        tokenizeNote: () => tokenizeNote
      });
      module.exports = __toCommonJS(pitch_note_exports);
      var import_pitch = require_dist14();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoNote = { empty: true, name: "", pc: "", acc: "" };
      var cache = /* @__PURE__ */ new Map();
      var stepToLetter = (step) => "CDEFGAB".charAt(step);
      var altToAcc = (alt) => alt < 0 ? fillStr("b", -alt) : fillStr("#", alt);
      var accToAlt = (acc) => acc[0] === "b" ? -acc.length : acc.length;
      function note(src) {
        const stringSrc = JSON.stringify(src);
        const cached = cache.get(stringSrc);
        if (cached) {
          return cached;
        }
        const value = typeof src === "string" ? parse2(src) : (0, import_pitch.isPitch)(src) ? note(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? note(src.name) : NoNote;
        cache.set(stringSrc, value);
        return value;
      }
      var REGEX = /^([a-gA-G]?)(#{1,}|b{1,}|x{1,}|)(-?\d*)\s*(.*)$/;
      function tokenizeNote(str) {
        const m3 = REGEX.exec(str);
        return m3 ? [m3[1].toUpperCase(), m3[2].replace(/x/g, "##"), m3[3], m3[4]] : ["", "", "", ""];
      }
      function coordToNote(noteCoord) {
        return note((0, import_pitch.pitch)(noteCoord));
      }
      var mod = (n2, m3) => (n2 % m3 + m3) % m3;
      var SEMI = [0, 2, 4, 5, 7, 9, 11];
      function parse2(noteName) {
        const tokens = tokenizeNote(noteName);
        if (tokens[0] === "" || tokens[3] !== "") {
          return NoNote;
        }
        const letter = tokens[0];
        const acc = tokens[1];
        const octStr = tokens[2];
        const step = (letter.charCodeAt(0) + 3) % 7;
        const alt = accToAlt(acc);
        const oct = octStr.length ? +octStr : void 0;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct });
        const name = letter + acc + octStr;
        const pc3 = letter + acc;
        const chroma = (SEMI[step] + alt + 120) % 12;
        const height = oct === void 0 ? mod(SEMI[step] + alt, 12) - 12 * 99 : SEMI[step] + alt + 12 * (oct + 1);
        const midi2 = height >= 0 && height <= 127 ? height : null;
        const freq = oct === void 0 ? null : Math.pow(2, (height - 69) / 12) * 440;
        return {
          empty: false,
          acc,
          alt,
          chroma,
          coord,
          freq,
          height,
          letter,
          midi: midi2,
          name,
          oct,
          pc: pc3,
          step
        };
      }
      function pitchName(props) {
        const { step, alt, oct } = props;
        const letter = stepToLetter(step);
        if (!letter) {
          return "";
        }
        const pc3 = letter + altToAcc(alt);
        return oct || oct === 0 ? pc3 + oct : pc3;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/core/node_modules/@tonaljs/pitch-distance/dist/index.js
  var require_dist17 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/core/node_modules/@tonaljs/pitch-distance/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_distance_exports = {};
      __export2(pitch_distance_exports, {
        distance: () => distance,
        tonicIntervalsTransposer: () => tonicIntervalsTransposer,
        transpose: () => transpose
      });
      module.exports = __toCommonJS(pitch_distance_exports);
      var import_pitch_interval = require_dist15();
      var import_pitch_note = require_dist16();
      function transpose(noteName, intervalName) {
        const note = (0, import_pitch_note.note)(noteName);
        const intervalCoord = Array.isArray(intervalName) ? intervalName : (0, import_pitch_interval.interval)(intervalName).coord;
        if (note.empty || !intervalCoord || intervalCoord.length < 2) {
          return "";
        }
        const noteCoord = note.coord;
        const tr2 = noteCoord.length === 1 ? [noteCoord[0] + intervalCoord[0]] : [noteCoord[0] + intervalCoord[0], noteCoord[1] + intervalCoord[1]];
        return (0, import_pitch_note.coordToNote)(tr2).name;
      }
      function tonicIntervalsTransposer(intervals, tonic) {
        const len = intervals.length;
        return (normalized) => {
          if (!tonic)
            return "";
          const index = normalized < 0 ? (len - -normalized % len) % len : normalized % len;
          const octaves = Math.floor(normalized / len);
          const root = transpose(tonic, [0, octaves]);
          return transpose(root, intervals[index]);
        };
      }
      function distance(fromNote, toNote) {
        const from = (0, import_pitch_note.note)(fromNote);
        const to3 = (0, import_pitch_note.note)(toNote);
        if (from.empty || to3.empty) {
          return "";
        }
        const fcoord = from.coord;
        const tcoord = to3.coord;
        const fifths = tcoord[0] - fcoord[0];
        const octs = fcoord.length === 2 && tcoord.length === 2 ? tcoord[1] - fcoord[1] : -Math.floor(fifths * 7 / 12);
        const forceDescending = to3.height === from.height && to3.midi !== null && from.midi !== null && from.step > to3.step;
        return (0, import_pitch_interval.coordToInterval)([fifths, octs], forceDescending).name;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/core/dist/index.js
  var require_dist18 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/core/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __reExport = (target, mod, secondTarget) => (__copyProps2(target, mod, "default"), secondTarget && __copyProps2(secondTarget, mod, "default"));
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var core_exports = {};
      __export2(core_exports, {
        deprecate: () => deprecate,
        fillStr: () => fillStr,
        isNamed: () => isNamed
      });
      module.exports = __toCommonJS(core_exports);
      var import_pitch = require_dist14();
      __reExport(core_exports, require_dist14(), module.exports);
      __reExport(core_exports, require_dist17(), module.exports);
      __reExport(core_exports, require_dist15(), module.exports);
      __reExport(core_exports, require_dist16(), module.exports);
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      function deprecate(original, alternative, fn3) {
        return function(...args) {
          console.warn(`${original} is deprecated. Use ${alternative}.`);
          return fn3.apply(this, args);
        };
      }
      var isNamed = deprecate("isNamed", "isNamedPitch", import_pitch.isNamedPitch);
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord-type/dist/index.js
  var require_dist19 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord-type/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var chord_type_exports = {};
      __export2(chord_type_exports, {
        add: () => add2,
        addAlias: () => addAlias,
        all: () => all,
        chordType: () => chordType,
        default: () => chord_type_default,
        entries: () => entries,
        get: () => get,
        keys: () => keys,
        names: () => names,
        removeAll: () => removeAll,
        symbols: () => symbols
      });
      module.exports = __toCommonJS(chord_type_exports);
      var import_core5 = require_dist18();
      var import_pcset = require_dist11();
      var CHORDS = [
        ["1P 3M 5P", "major", "M ^  maj"],
        ["1P 3M 5P 7M", "major seventh", "maj7 \u0394 ma7 M7 Maj7 ^7"],
        ["1P 3M 5P 7M 9M", "major ninth", "maj9 \u03949 ^9"],
        ["1P 3M 5P 7M 9M 13M", "major thirteenth", "maj13 Maj13 ^13"],
        ["1P 3M 5P 6M", "sixth", "6 add6 add13 M6"],
        ["1P 3M 5P 6M 9M", "sixth added ninth", "6add9 6/9 69 M69"],
        ["1P 3M 6m 7M", "major seventh flat sixth", "M7b6 ^7b6"],
        [
          "1P 3M 5P 7M 11A",
          "major seventh sharp eleventh",
          "maj#4 \u0394#4 \u0394#11 M7#11 ^7#11 maj7#11"
        ],
        ["1P 3m 5P", "minor", "m min -"],
        ["1P 3m 5P 7m", "minor seventh", "m7 min7 mi7 -7"],
        [
          "1P 3m 5P 7M",
          "minor/major seventh",
          "m/ma7 m/maj7 mM7 mMaj7 m/M7 -\u03947 m\u0394 -^7"
        ],
        ["1P 3m 5P 6M", "minor sixth", "m6 -6"],
        ["1P 3m 5P 7m 9M", "minor ninth", "m9 -9"],
        ["1P 3m 5P 7M 9M", "minor/major ninth", "mM9 mMaj9 -^9"],
        ["1P 3m 5P 7m 9M 11P", "minor eleventh", "m11 -11"],
        ["1P 3m 5P 7m 9M 13M", "minor thirteenth", "m13 -13"],
        ["1P 3m 5d", "diminished", "dim \xB0 o"],
        ["1P 3m 5d 7d", "diminished seventh", "dim7 \xB07 o7"],
        ["1P 3m 5d 7m", "half-diminished", "m7b5 \xF8 -7b5 h7 h"],
        ["1P 3M 5P 7m", "dominant seventh", "7 dom"],
        ["1P 3M 5P 7m 9M", "dominant ninth", "9"],
        ["1P 3M 5P 7m 9M 13M", "dominant thirteenth", "13"],
        ["1P 3M 5P 7m 11A", "lydian dominant seventh", "7#11 7#4"],
        ["1P 3M 5P 7m 9m", "dominant flat ninth", "7b9"],
        ["1P 3M 5P 7m 9A", "dominant sharp ninth", "7#9"],
        ["1P 3M 7m 9m", "altered", "alt7"],
        ["1P 4P 5P", "suspended fourth", "sus4 sus"],
        ["1P 2M 5P", "suspended second", "sus2"],
        ["1P 4P 5P 7m", "suspended fourth seventh", "7sus4 7sus"],
        ["1P 5P 7m 9M 11P", "eleventh", "11"],
        [
          "1P 4P 5P 7m 9m",
          "suspended fourth flat ninth",
          "b9sus phryg 7b9sus 7b9sus4"
        ],
        ["1P 5P", "fifth", "5"],
        ["1P 3M 5A", "augmented", "aug + +5 ^#5"],
        ["1P 3m 5A", "minor augmented", "m#5 -#5 m+"],
        ["1P 3M 5A 7M", "augmented seventh", "maj7#5 maj7+5 +maj7 ^7#5"],
        [
          "1P 3M 5P 7M 9M 11A",
          "major sharp eleventh (lydian)",
          "maj9#11 \u03949#11 ^9#11"
        ],
        ["1P 2M 4P 5P", "", "sus24 sus4add9"],
        ["1P 3M 5A 7M 9M", "", "maj9#5 Maj9#5"],
        ["1P 3M 5A 7m", "", "7#5 +7 7+ 7aug aug7"],
        ["1P 3M 5A 7m 9A", "", "7#5#9 7#9#5 7alt"],
        ["1P 3M 5A 7m 9M", "", "9#5 9+"],
        ["1P 3M 5A 7m 9M 11A", "", "9#5#11"],
        ["1P 3M 5A 7m 9m", "", "7#5b9 7b9#5"],
        ["1P 3M 5A 7m 9m 11A", "", "7#5b9#11"],
        ["1P 3M 5A 9A", "", "+add#9"],
        ["1P 3M 5A 9M", "", "M#5add9 +add9"],
        ["1P 3M 5P 6M 11A", "", "M6#11 M6b5 6#11 6b5"],
        ["1P 3M 5P 6M 7M 9M", "", "M7add13"],
        ["1P 3M 5P 6M 9M 11A", "", "69#11"],
        ["1P 3m 5P 6M 9M", "", "m69 -69"],
        ["1P 3M 5P 6m 7m", "", "7b6"],
        ["1P 3M 5P 7M 9A 11A", "", "maj7#9#11"],
        ["1P 3M 5P 7M 9M 11A 13M", "", "M13#11 maj13#11 M13+4 M13#4"],
        ["1P 3M 5P 7M 9m", "", "M7b9"],
        ["1P 3M 5P 7m 11A 13m", "", "7#11b13 7b5b13"],
        ["1P 3M 5P 7m 13M", "", "7add6 67 7add13"],
        ["1P 3M 5P 7m 9A 11A", "", "7#9#11 7b5#9 7#9b5"],
        ["1P 3M 5P 7m 9A 11A 13M", "", "13#9#11"],
        ["1P 3M 5P 7m 9A 11A 13m", "", "7#9#11b13"],
        ["1P 3M 5P 7m 9A 13M", "", "13#9"],
        ["1P 3M 5P 7m 9A 13m", "", "7#9b13"],
        ["1P 3M 5P 7m 9M 11A", "", "9#11 9+4 9#4"],
        ["1P 3M 5P 7m 9M 11A 13M", "", "13#11 13+4 13#4"],
        ["1P 3M 5P 7m 9M 11A 13m", "", "9#11b13 9b5b13"],
        ["1P 3M 5P 7m 9m 11A", "", "7b9#11 7b5b9 7b9b5"],
        ["1P 3M 5P 7m 9m 11A 13M", "", "13b9#11"],
        ["1P 3M 5P 7m 9m 11A 13m", "", "7b9b13#11 7b9#11b13 7b5b9b13"],
        ["1P 3M 5P 7m 9m 13M", "", "13b9"],
        ["1P 3M 5P 7m 9m 13m", "", "7b9b13"],
        ["1P 3M 5P 7m 9m 9A", "", "7b9#9"],
        ["1P 3M 5P 9M", "", "Madd9 2 add9 add2"],
        ["1P 3M 5P 9m", "", "Maddb9"],
        ["1P 3M 5d", "", "Mb5"],
        ["1P 3M 5d 6M 7m 9M", "", "13b5"],
        ["1P 3M 5d 7M", "", "M7b5"],
        ["1P 3M 5d 7M 9M", "", "M9b5"],
        ["1P 3M 5d 7m", "", "7b5"],
        ["1P 3M 5d 7m 9M", "", "9b5"],
        ["1P 3M 7m", "", "7no5"],
        ["1P 3M 7m 13m", "", "7b13"],
        ["1P 3M 7m 9M", "", "9no5"],
        ["1P 3M 7m 9M 13M", "", "13no5"],
        ["1P 3M 7m 9M 13m", "", "9b13"],
        ["1P 3m 4P 5P", "", "madd4"],
        ["1P 3m 5P 6m 7M", "", "mMaj7b6"],
        ["1P 3m 5P 6m 7M 9M", "", "mMaj9b6"],
        ["1P 3m 5P 7m 11P", "", "m7add11 m7add4"],
        ["1P 3m 5P 9M", "", "madd9"],
        ["1P 3m 5d 6M 7M", "", "o7M7"],
        ["1P 3m 5d 7M", "", "oM7"],
        ["1P 3m 6m 7M", "", "mb6M7"],
        ["1P 3m 6m 7m", "", "m7#5"],
        ["1P 3m 6m 7m 9M", "", "m9#5"],
        ["1P 3m 5A 7m 9M 11P", "", "m11A"],
        ["1P 3m 6m 9m", "", "mb6b9"],
        ["1P 2M 3m 5d 7m", "", "m9b5"],
        ["1P 4P 5A 7M", "", "M7#5sus4"],
        ["1P 4P 5A 7M 9M", "", "M9#5sus4"],
        ["1P 4P 5A 7m", "", "7#5sus4"],
        ["1P 4P 5P 7M", "", "M7sus4"],
        ["1P 4P 5P 7M 9M", "", "M9sus4"],
        ["1P 4P 5P 7m 9M", "", "9sus4 9sus"],
        ["1P 4P 5P 7m 9M 13M", "", "13sus4 13sus"],
        ["1P 4P 5P 7m 9m 13m", "", "7sus4b9b13 7b9b13sus4"],
        ["1P 4P 7m 10m", "", "4 quartal"],
        ["1P 5P 7m 9m 11P", "", "11b9"]
      ];
      var data_default = CHORDS;
      var NoChordType = {
        ...import_pcset.EmptyPcset,
        name: "",
        quality: "Unknown",
        intervals: [],
        aliases: []
      };
      var dictionary = [];
      var index = {};
      function get(type) {
        return index[type] || NoChordType;
      }
      var chordType = (0, import_core5.deprecate)("ChordType.chordType", "ChordType.get", get);
      function names() {
        return dictionary.map((chord) => chord.name).filter((x2) => x2);
      }
      function symbols() {
        return dictionary.map((chord) => chord.aliases[0]).filter((x2) => x2);
      }
      function keys() {
        return Object.keys(index);
      }
      function all() {
        return dictionary.slice();
      }
      var entries = (0, import_core5.deprecate)("ChordType.entries", "ChordType.all", all);
      function removeAll() {
        dictionary = [];
        index = {};
      }
      function add2(intervals, aliases, fullName) {
        const quality = getQuality(intervals);
        const chord = {
          ...(0, import_pcset.get)(intervals),
          name: fullName || "",
          quality,
          intervals,
          aliases
        };
        dictionary.push(chord);
        if (chord.name) {
          index[chord.name] = chord;
        }
        index[chord.setNum] = chord;
        index[chord.chroma] = chord;
        chord.aliases.forEach((alias) => addAlias(chord, alias));
      }
      function addAlias(chord, alias) {
        index[alias] = chord;
      }
      function getQuality(intervals) {
        const has = (interval) => intervals.indexOf(interval) !== -1;
        return has("5A") ? "Augmented" : has("3M") ? "Major" : has("5d") ? "Diminished" : has("3m") ? "Minor" : "Unknown";
      }
      data_default.forEach(
        ([ivls, fullName, names2]) => add2(ivls.split(" "), names2.split(" "), fullName)
      );
      dictionary.sort((a2, b2) => a2.setNum - b2.setNum);
      var chord_type_default = {
        names,
        symbols,
        get,
        all,
        add: add2,
        removeAll,
        keys,
        entries,
        chordType
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/scale-type/dist/index.js
  var require_dist20 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/scale-type/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        NoScaleType: () => NoScaleType,
        add: () => add2,
        addAlias: () => addAlias,
        all: () => all,
        default: () => index_default,
        entries: () => entries,
        get: () => get,
        keys: () => keys,
        names: () => names,
        removeAll: () => removeAll,
        scaleType: () => scaleType
      });
      module.exports = __toCommonJS(index_exports);
      var import_pcset = require_dist11();
      var SCALES = [
        // Basic scales
        ["1P 2M 3M 5P 6M", "major pentatonic", "pentatonic"],
        ["1P 2M 3M 4P 5P 6M 7M", "major", "ionian"],
        ["1P 2M 3m 4P 5P 6m 7m", "minor", "aeolian"],
        // Jazz common scales
        ["1P 2M 3m 3M 5P 6M", "major blues"],
        ["1P 3m 4P 5d 5P 7m", "minor blues", "blues"],
        ["1P 2M 3m 4P 5P 6M 7M", "melodic minor"],
        ["1P 2M 3m 4P 5P 6m 7M", "harmonic minor"],
        ["1P 2M 3M 4P 5P 6M 7m 7M", "bebop"],
        ["1P 2M 3m 4P 5d 6m 6M 7M", "diminished", "whole-half diminished"],
        // Modes
        ["1P 2M 3m 4P 5P 6M 7m", "dorian"],
        ["1P 2M 3M 4A 5P 6M 7M", "lydian"],
        ["1P 2M 3M 4P 5P 6M 7m", "mixolydian", "dominant"],
        ["1P 2m 3m 4P 5P 6m 7m", "phrygian"],
        ["1P 2m 3m 4P 5d 6m 7m", "locrian"],
        // 5-note scales
        ["1P 3M 4P 5P 7M", "ionian pentatonic"],
        ["1P 3M 4P 5P 7m", "mixolydian pentatonic", "indian"],
        ["1P 2M 4P 5P 6M", "ritusen"],
        ["1P 2M 4P 5P 7m", "egyptian"],
        // Source: https://en.wikipedia.org/wiki/Neapolitan_scale
        ["1P 3M 4P 5d 7m", "neapolitan major pentatonic"],
        ["1P 3m 4P 5P 6m", "vietnamese 1"],
        ["1P 2m 3m 5P 6m", "pelog"],
        ["1P 2m 4P 5P 6m", "kumoijoshi"],
        ["1P 2M 3m 5P 6m", "hirajoshi"],
        ["1P 2m 4P 5d 7m", "iwato"],
        ["1P 2m 4P 5P 7m", "in-sen"],
        ["1P 3M 4A 5P 7M", "lydian pentatonic", "chinese"],
        ["1P 3m 4P 6m 7m", "malkos raga"],
        ["1P 3m 4P 5d 7m", "locrian pentatonic", "minor seven flat five pentatonic"],
        ["1P 3m 4P 5P 7m", "minor pentatonic", "vietnamese 2"],
        ["1P 3m 4P 5P 6M", "minor six pentatonic"],
        ["1P 2M 3m 5P 6M", "flat three pentatonic", "kumoi"],
        ["1P 2M 3M 5P 6m", "flat six pentatonic"],
        ["1P 2m 3M 5P 6M", "scriabin"],
        ["1P 3M 5d 6m 7m", "whole tone pentatonic"],
        ["1P 3M 4A 5A 7M", "lydian #5p pentatonic"],
        ["1P 3M 4A 5P 7m", "lydian dominant pentatonic"],
        ["1P 3m 4P 5P 7M", "minor #7m pentatonic"],
        ["1P 3m 4d 5d 7m", "super locrian pentatonic"],
        // 6-note scales
        ["1P 2M 3m 4P 5P 7M", "minor hexatonic"],
        ["1P 2A 3M 5P 5A 7M", "augmented"],
        ["1P 2M 4P 5P 6M 7m", "piongio"],
        // Source: https://en.wikipedia.org/wiki/Neapolitan_scale
        ["1P 2m 3M 4A 6M 7m", "prometheus neapolitan"],
        ["1P 2M 3M 4A 6M 7m", "prometheus"],
        ["1P 2m 3M 5d 6m 7m", "mystery #1"],
        ["1P 2m 3M 4P 5A 6M", "six tone symmetric"],
        ["1P 2M 3M 4A 5A 6A", "whole tone", "messiaen's mode #1"],
        ["1P 2m 4P 4A 5P 7M", "messiaen's mode #5"],
        // 7-note scales
        ["1P 2M 3M 4P 5d 6m 7m", "locrian major", "arabian"],
        ["1P 2m 3M 4A 5P 6m 7M", "double harmonic lydian"],
        [
          "1P 2m 2A 3M 4A 6m 7m",
          "altered",
          "super locrian",
          "diminished whole tone",
          "pomeroy"
        ],
        ["1P 2M 3m 4P 5d 6m 7m", "locrian #2", "half-diminished", "aeolian b5"],
        [
          "1P 2M 3M 4P 5P 6m 7m",
          "mixolydian b6",
          "melodic minor fifth mode",
          "hindu"
        ],
        ["1P 2M 3M 4A 5P 6M 7m", "lydian dominant", "lydian b7", "overtone"],
        ["1P 2M 3M 4A 5A 6M 7M", "lydian augmented"],
        [
          "1P 2m 3m 4P 5P 6M 7m",
          "dorian b2",
          "phrygian #6",
          "melodic minor second mode"
        ],
        [
          "1P 2m 3m 4d 5d 6m 7d",
          "ultralocrian",
          "superlocrian bb7",
          "superlocrian diminished"
        ],
        ["1P 2m 3m 4P 5d 6M 7m", "locrian 6", "locrian natural 6", "locrian sharp 6"],
        ["1P 2A 3M 4P 5P 5A 7M", "augmented heptatonic"],
        // Source https://en.wikipedia.org/wiki/Ukrainian_Dorian_scale
        [
          "1P 2M 3m 4A 5P 6M 7m",
          "dorian #4",
          "ukrainian dorian",
          "romanian minor",
          "altered dorian"
        ],
        ["1P 2M 3m 4A 5P 6M 7M", "lydian diminished"],
        ["1P 2M 3M 4A 5A 7m 7M", "leading whole tone"],
        ["1P 2M 3M 4A 5P 6m 7m", "lydian minor"],
        ["1P 2m 3M 4P 5P 6m 7m", "phrygian dominant", "spanish", "phrygian major"],
        ["1P 2m 3m 4P 5P 6m 7M", "balinese"],
        // Source: https://en.wikipedia.org/wiki/Neapolitan_scale
        ["1P 2m 3m 4P 5P 6M 7M", "neapolitan major"],
        ["1P 2M 3M 4P 5P 6m 7M", "harmonic major"],
        ["1P 2m 3M 4P 5P 6m 7M", "double harmonic major", "gypsy"],
        ["1P 2M 3m 4A 5P 6m 7M", "hungarian minor"],
        ["1P 2A 3M 4A 5P 6M 7m", "hungarian major"],
        ["1P 2m 3M 4P 5d 6M 7m", "oriental"],
        ["1P 2m 3m 3M 4A 5P 7m", "flamenco"],
        ["1P 2m 3m 4A 5P 6m 7M", "todi raga"],
        ["1P 2m 3M 4P 5d 6m 7M", "persian"],
        ["1P 2m 3M 5d 6m 7m 7M", "enigmatic"],
        [
          "1P 2M 3M 4P 5A 6M 7M",
          "major augmented",
          "major #5",
          "ionian augmented",
          "ionian #5"
        ],
        ["1P 2A 3M 4A 5P 6M 7M", "lydian #9"],
        // 8-note scales
        ["1P 2m 2M 4P 4A 5P 6m 7M", "messiaen's mode #4"],
        ["1P 2m 3M 4P 4A 5P 6m 7M", "purvi raga"],
        ["1P 2m 3m 3M 4P 5P 6m 7m", "spanish heptatonic"],
        ["1P 2M 3m 3M 4P 5P 6M 7m", "bebop minor"],
        ["1P 2M 3M 4P 5P 5A 6M 7M", "bebop major"],
        ["1P 2m 3m 4P 5d 5P 6m 7m", "bebop locrian"],
        ["1P 2M 3m 4P 5P 6m 7m 7M", "minor bebop"],
        ["1P 2M 3M 4P 5d 5P 6M 7M", "ichikosucho"],
        ["1P 2M 3m 4P 5P 6m 6M 7M", "minor six diminished"],
        [
          "1P 2m 3m 3M 4A 5P 6M 7m",
          "half-whole diminished",
          "dominant diminished",
          "messiaen's mode #2"
        ],
        ["1P 3m 3M 4P 5P 6M 7m 7M", "kafi raga"],
        ["1P 2M 3M 4P 4A 5A 6A 7M", "messiaen's mode #6"],
        // 9-note scales
        ["1P 2M 3m 3M 4P 5d 5P 6M 7m", "composite blues"],
        ["1P 2M 3m 3M 4A 5P 6m 7m 7M", "messiaen's mode #3"],
        // 10-note scales
        ["1P 2m 2M 3m 4P 4A 5P 6m 6M 7M", "messiaen's mode #7"],
        // 12-note scales
        ["1P 2m 2M 3m 3M 4P 5d 5P 6m 6M 7m 7M", "chromatic"]
      ];
      var data_default = SCALES;
      var NoScaleType = {
        ...import_pcset.EmptyPcset,
        intervals: [],
        aliases: []
      };
      var dictionary = [];
      var index = {};
      function names() {
        return dictionary.map((scale) => scale.name);
      }
      function get(type) {
        return index[type] || NoScaleType;
      }
      var scaleType = get;
      function all() {
        return dictionary.slice();
      }
      var entries = all;
      function keys() {
        return Object.keys(index);
      }
      function removeAll() {
        dictionary = [];
        index = {};
      }
      function add2(intervals, name, aliases = []) {
        const scale = { ...(0, import_pcset.get)(intervals), name, intervals, aliases };
        dictionary.push(scale);
        index[scale.name] = scale;
        index[scale.setNum] = scale;
        index[scale.chroma] = scale;
        scale.aliases.forEach((alias) => addAlias(scale, alias));
        return scale;
      }
      function addAlias(scale, alias) {
        index[alias] = scale;
      }
      data_default.forEach(
        ([ivls, name, ...aliases]) => add2(ivls.split(" "), name, aliases)
      );
      var index_default = {
        names,
        get,
        all,
        add: add2,
        removeAll,
        keys,
        // deprecated
        entries,
        scaleType
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord/dist/index.js
  var require_dist21 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/chord/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var chord_exports = {};
      __export2(chord_exports, {
        chord: () => chord,
        chordScales: () => chordScales,
        default: () => chord_default,
        degrees: () => degrees,
        detect: () => import_chord_detect2.detect,
        extended: () => extended,
        get: () => get,
        getChord: () => getChord,
        reduced: () => reduced,
        steps: () => steps,
        tokenize: () => tokenize,
        transpose: () => transpose
      });
      module.exports = __toCommonJS(chord_exports);
      var import_chord_detect = require_dist13();
      var import_chord_type = require_dist19();
      var import_core5 = require_dist18();
      var import_core22 = require_dist18();
      var import_pcset = require_dist11();
      var import_scale_type = require_dist20();
      var import_chord_detect2 = require_dist13();
      var NoChord = {
        empty: true,
        name: "",
        symbol: "",
        root: "",
        rootDegree: 0,
        type: "",
        tonic: null,
        setNum: NaN,
        quality: "Unknown",
        chroma: "",
        normalized: "",
        aliases: [],
        notes: [],
        intervals: []
      };
      function tokenize(name) {
        const [letter, acc, oct, type] = (0, import_core22.tokenizeNote)(name);
        if (letter === "") {
          return ["", name];
        }
        if (letter === "A" && type === "ug") {
          return ["", "aug"];
        }
        return [letter + acc, oct + type];
      }
      function get(src) {
        if (src === "") {
          return NoChord;
        }
        if (Array.isArray(src) && src.length === 2) {
          return getChord(src[1], src[0]);
        } else {
          const [tonic, type] = tokenize(src);
          const chord2 = getChord(type, tonic);
          return chord2.empty ? getChord(src) : chord2;
        }
      }
      function getChord(typeName, optionalTonic, optionalRoot) {
        const type = (0, import_chord_type.get)(typeName);
        const tonic = (0, import_core22.note)(optionalTonic || "");
        const root = (0, import_core22.note)(optionalRoot || "");
        if (type.empty || optionalTonic && tonic.empty || optionalRoot && root.empty) {
          return NoChord;
        }
        const rootInterval = (0, import_core22.distance)(tonic.pc, root.pc);
        const rootDegree = type.intervals.indexOf(rootInterval) + 1;
        if (!root.empty && !rootDegree) {
          return NoChord;
        }
        const intervals = Array.from(type.intervals);
        for (let i = 1; i < rootDegree; i++) {
          const num = intervals[0][0];
          const quality = intervals[0][1];
          const newNum = parseInt(num, 10) + 7;
          intervals.push(`${newNum}${quality}`);
          intervals.shift();
        }
        const notes = tonic.empty ? [] : intervals.map((i) => (0, import_core22.transpose)(tonic, i));
        typeName = type.aliases.indexOf(typeName) !== -1 ? typeName : type.aliases[0];
        const symbol = `${tonic.empty ? "" : tonic.pc}${typeName}${root.empty || rootDegree <= 1 ? "" : "/" + root.pc}`;
        const name = `${optionalTonic ? tonic.pc + " " : ""}${type.name}${rootDegree > 1 && optionalRoot ? " over " + root.pc : ""}`;
        return {
          ...type,
          name,
          symbol,
          type: type.name,
          root: root.name,
          intervals,
          rootDegree,
          tonic: tonic.name,
          notes
        };
      }
      var chord = (0, import_core22.deprecate)("Chord.chord", "Chord.get", get);
      function transpose(chordName, interval) {
        const [tonic, type] = tokenize(chordName);
        if (!tonic) {
          return chordName;
        }
        return (0, import_core22.transpose)(tonic, interval) + type;
      }
      function chordScales(name) {
        const s2 = get(name);
        const isChordIncluded = (0, import_pcset.isSupersetOf)(s2.chroma);
        return (0, import_scale_type.all)().filter((scale) => isChordIncluded(scale.chroma)).map((scale) => scale.name);
      }
      function extended(chordName) {
        const s2 = get(chordName);
        const isSuperset = (0, import_pcset.isSupersetOf)(s2.chroma);
        return (0, import_chord_type.all)().filter((chord2) => isSuperset(chord2.chroma)).map((chord2) => s2.tonic + chord2.aliases[0]);
      }
      function reduced(chordName) {
        const s2 = get(chordName);
        const isSubset = (0, import_pcset.isSubsetOf)(s2.chroma);
        return (0, import_chord_type.all)().filter((chord2) => isSubset(chord2.chroma)).map((chord2) => s2.tonic + chord2.aliases[0]);
      }
      function degrees(chordName) {
        const { intervals, tonic } = get(chordName);
        const transpose2 = (0, import_core5.tonicIntervalsTransposer)(intervals, tonic);
        return (degree) => degree ? transpose2(degree > 0 ? degree - 1 : degree) : "";
      }
      function steps(chordName) {
        const { intervals, tonic } = get(chordName);
        return (0, import_core5.tonicIntervalsTransposer)(intervals, tonic);
      }
      var chord_default = {
        getChord,
        get,
        detect: import_chord_detect.detect,
        chordScales,
        extended,
        reduced,
        tokenize,
        transpose,
        degrees,
        steps,
        chord
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/duration-value/dist/index.js
  var require_dist22 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/duration-value/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var duration_value_exports = {};
      __export2(duration_value_exports, {
        default: () => duration_value_default,
        fraction: () => fraction,
        get: () => get,
        names: () => names,
        shorthands: () => shorthands,
        value: () => value
      });
      module.exports = __toCommonJS(duration_value_exports);
      var DATA = [
        [
          0.125,
          "dl",
          ["large", "duplex longa", "maxima", "octuple", "octuple whole"]
        ],
        [0.25, "l", ["long", "longa"]],
        [0.5, "d", ["double whole", "double", "breve"]],
        [1, "w", ["whole", "semibreve"]],
        [2, "h", ["half", "minim"]],
        [4, "q", ["quarter", "crotchet"]],
        [8, "e", ["eighth", "quaver"]],
        [16, "s", ["sixteenth", "semiquaver"]],
        [32, "t", ["thirty-second", "demisemiquaver"]],
        [64, "sf", ["sixty-fourth", "hemidemisemiquaver"]],
        [128, "h", ["hundred twenty-eighth"]],
        [256, "th", ["two hundred fifty-sixth"]]
      ];
      var data_default = DATA;
      var VALUES = [];
      data_default.forEach(
        ([denominator, shorthand, names2]) => add2(denominator, shorthand, names2)
      );
      var NoDuration = {
        empty: true,
        name: "",
        value: 0,
        fraction: [0, 0],
        shorthand: "",
        dots: "",
        names: []
      };
      function names() {
        return VALUES.reduce((names2, duration) => {
          duration.names.forEach((name) => names2.push(name));
          return names2;
        }, []);
      }
      function shorthands() {
        return VALUES.map((dur) => dur.shorthand);
      }
      var REGEX = /^([^.]+)(\.*)$/;
      function get(name) {
        const [_5, simple, dots] = REGEX.exec(name) || [];
        const base = VALUES.find(
          (dur) => dur.shorthand === simple || dur.names.includes(simple)
        );
        if (!base) {
          return NoDuration;
        }
        const fraction2 = calcDots(base.fraction, dots.length);
        const value2 = fraction2[0] / fraction2[1];
        return { ...base, name, dots, value: value2, fraction: fraction2 };
      }
      var value = (name) => get(name).value;
      var fraction = (name) => get(name).fraction;
      var duration_value_default = { names, shorthands, get, value, fraction };
      function add2(denominator, shorthand, names2) {
        VALUES.push({
          empty: false,
          dots: "",
          name: "",
          value: 1 / denominator,
          fraction: denominator < 1 ? [1 / denominator, 1] : [1, denominator],
          shorthand,
          names: names2
        });
      }
      function calcDots(fraction2, dots) {
        const pow = Math.pow(2, dots);
        let numerator = fraction2[0] * pow;
        let denominator = fraction2[1] * pow;
        const base = numerator;
        for (let i = 0; i < dots; i++) {
          numerator += base / Math.pow(2, i + 1);
        }
        while (numerator % 2 === 0 && denominator % 2 === 0) {
          numerator /= 2;
          denominator /= 2;
        }
        return [numerator, denominator];
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/interval/dist/index.js
  var require_dist23 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name2 in all)
          __defProp2(target, name2, { get: all[name2], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var interval_exports = {};
      __export2(interval_exports, {
        add: () => add2,
        addTo: () => addTo,
        default: () => interval_default,
        distance: () => distance,
        fromSemitones: () => fromSemitones,
        get: () => get,
        invert: () => invert,
        name: () => name,
        names: () => names,
        num: () => num,
        quality: () => quality,
        semitones: () => semitones,
        simplify: () => simplify,
        substract: () => substract,
        transposeFifths: () => transposeFifths
      });
      module.exports = __toCommonJS(interval_exports);
      var import_pitch_distance = require_dist5();
      var import_pitch_interval = require_dist15();
      function names() {
        return "1P 2M 3M 4P 5P 6m 7m".split(" ");
      }
      var get = import_pitch_interval.interval;
      var name = (name2) => (0, import_pitch_interval.interval)(name2).name;
      var semitones = (name2) => (0, import_pitch_interval.interval)(name2).semitones;
      var quality = (name2) => (0, import_pitch_interval.interval)(name2).q;
      var num = (name2) => (0, import_pitch_interval.interval)(name2).num;
      function simplify(name2) {
        const i = (0, import_pitch_interval.interval)(name2);
        return i.empty ? "" : i.simple + i.q;
      }
      function invert(name2) {
        const i = (0, import_pitch_interval.interval)(name2);
        if (i.empty) {
          return "";
        }
        const step = (7 - i.step) % 7;
        const alt = i.type === "perfectable" ? -i.alt : -(i.alt + 1);
        return (0, import_pitch_interval.interval)({ step, alt, oct: i.oct, dir: i.dir }).name;
      }
      var IN = [1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 7];
      var IQ = "P m M m M P d P m M m M".split(" ");
      function fromSemitones(semitones2) {
        const d2 = semitones2 < 0 ? -1 : 1;
        const n2 = Math.abs(semitones2);
        const c3 = n2 % 12;
        const o = Math.floor(n2 / 12);
        return d2 * (IN[c3] + 7 * o) + IQ[c3];
      }
      var distance = import_pitch_distance.distance;
      var add2 = combinator((a2, b2) => [a2[0] + b2[0], a2[1] + b2[1]]);
      var addTo = (interval) => (other) => add2(interval, other);
      var substract = combinator((a2, b2) => [a2[0] - b2[0], a2[1] - b2[1]]);
      function transposeFifths(interval, fifths) {
        const ivl = get(interval);
        if (ivl.empty)
          return "";
        const [nFifths, nOcts, dir] = ivl.coord;
        return (0, import_pitch_interval.coordToInterval)([nFifths + fifths, nOcts, dir]).name;
      }
      var interval_default = {
        names,
        get,
        name,
        num,
        semitones,
        quality,
        fromSemitones,
        distance,
        invert,
        simplify,
        add: add2,
        addTo,
        substract,
        transposeFifths
      };
      function combinator(fn3) {
        return (a2, b2) => {
          const coordA = (0, import_pitch_interval.interval)(a2).coord;
          const coordB = (0, import_pitch_interval.interval)(b2).coord;
          if (coordA && coordB) {
            const coord = fn3(coordA, coordB);
            return (0, import_pitch_interval.coordToInterval)(coord).name;
          }
        };
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/midi/dist/index.js
  var require_dist24 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/midi/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        chroma: () => chroma,
        default: () => index_default,
        freqToMidi: () => freqToMidi,
        isMidi: () => isMidi,
        midiToFreq: () => midiToFreq,
        midiToNoteName: () => midiToNoteName,
        pcset: () => pcset,
        pcsetDegrees: () => pcsetDegrees,
        pcsetNearest: () => pcsetNearest,
        pcsetSteps: () => pcsetSteps,
        toMidi: () => toMidi
      });
      module.exports = __toCommonJS(index_exports);
      var import_pitch_note = require_dist4();
      function isMidi(arg) {
        return +arg >= 0 && +arg <= 127;
      }
      function toMidi(note) {
        if (isMidi(note)) {
          return +note;
        }
        const n2 = (0, import_pitch_note.note)(note);
        return n2.empty ? null : n2.midi;
      }
      function midiToFreq(midi2, tuning = 440) {
        return Math.pow(2, (midi2 - 69) / 12) * tuning;
      }
      var L22 = Math.log(2);
      var L440 = Math.log(440);
      function freqToMidi(freq) {
        const v2 = 12 * (Math.log(freq) - L440) / L22 + 69;
        return Math.round(v2 * 100) / 100;
      }
      var SHARPS = "C C# D D# E F F# G G# A A# B".split(" ");
      var FLATS = "C Db D Eb E F Gb G Ab A Bb B".split(" ");
      function midiToNoteName(midi2, options = {}) {
        if (isNaN(midi2) || midi2 === -Infinity || midi2 === Infinity) return "";
        midi2 = Math.round(midi2);
        const pcs = options.sharps === true ? SHARPS : FLATS;
        const pc3 = pcs[midi2 % 12];
        if (options.pitchClass) {
          return pc3;
        }
        const o = Math.floor(midi2 / 12) - 1;
        return pc3 + o;
      }
      function chroma(midi2) {
        return midi2 % 12;
      }
      function pcsetFromChroma(chroma2) {
        return chroma2.split("").reduce((pcset2, val, index) => {
          if (index < 12 && val === "1") pcset2.push(index);
          return pcset2;
        }, []);
      }
      function pcsetFromMidi(midi2) {
        return midi2.map(chroma).sort((a2, b2) => a2 - b2).filter((n2, i, a2) => i === 0 || n2 !== a2[i - 1]);
      }
      function pcset(notes) {
        return Array.isArray(notes) ? pcsetFromMidi(notes) : pcsetFromChroma(notes);
      }
      function pcsetNearest(notes) {
        const set = pcset(notes);
        return (midi2) => {
          const ch2 = chroma(midi2);
          for (let i = 0; i < 12; i++) {
            if (set.includes(ch2 + i)) return midi2 + i;
            if (set.includes(ch2 - i)) return midi2 - i;
          }
          return void 0;
        };
      }
      function pcsetSteps(notes, tonic) {
        const set = pcset(notes);
        const len = set.length;
        return (step) => {
          const index = step < 0 ? (len - -step % len) % len : step % len;
          const octaves = Math.floor(step / len);
          return set[index] + octaves * 12 + tonic;
        };
      }
      function pcsetDegrees(notes, tonic) {
        const steps = pcsetSteps(notes, tonic);
        return (degree) => {
          if (degree === 0) return void 0;
          return steps(degree > 0 ? degree - 1 : degree);
        };
      }
      var index_default = {
        chroma,
        freqToMidi,
        isMidi,
        midiToFreq,
        midiToNoteName,
        pcsetNearest,
        pcset,
        pcsetDegrees,
        pcsetSteps,
        toMidi
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/note/dist/index.js
  var require_dist25 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/note/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name2 in all)
          __defProp2(target, name2, { get: all[name2], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        accidentals: () => accidentals,
        ascending: () => ascending,
        chroma: () => chroma,
        default: () => index_default,
        descending: () => descending,
        distance: () => distance,
        enharmonic: () => enharmonic,
        freq: () => freq,
        fromFreq: () => fromFreq,
        fromFreqSharps: () => fromFreqSharps,
        fromMidi: () => fromMidi,
        fromMidiSharps: () => fromMidiSharps,
        get: () => get,
        midi: () => midi2,
        name: () => name,
        names: () => names,
        octave: () => octave,
        pitchClass: () => pitchClass,
        simplify: () => simplify,
        sortedNames: () => sortedNames,
        sortedUniqNames: () => sortedUniqNames,
        tr: () => tr2,
        trBy: () => trBy,
        trFifths: () => trFifths,
        trFrom: () => trFrom,
        transpose: () => transpose,
        transposeBy: () => transposeBy,
        transposeFifths: () => transposeFifths,
        transposeFrom: () => transposeFrom,
        transposeOctaves: () => transposeOctaves
      });
      module.exports = __toCommonJS(index_exports);
      var import_midi = require_dist24();
      var import_pitch_distance = require_dist5();
      var import_pitch_note = require_dist4();
      var NAMES = ["C", "D", "E", "F", "G", "A", "B"];
      var toName = (n2) => n2.name;
      var onlyNotes = (array) => array.map(import_pitch_note.note).filter((n2) => !n2.empty);
      function names(array) {
        if (array === void 0) {
          return NAMES.slice();
        } else if (!Array.isArray(array)) {
          return [];
        } else {
          return onlyNotes(array).map(toName);
        }
      }
      var get = import_pitch_note.note;
      var name = (note) => get(note).name;
      var pitchClass = (note) => get(note).pc;
      var accidentals = (note) => get(note).acc;
      var octave = (note) => get(note).oct;
      var midi2 = (note) => get(note).midi;
      var freq = (note) => get(note).freq;
      var chroma = (note) => get(note).chroma;
      function fromMidi(midi22) {
        return (0, import_midi.midiToNoteName)(midi22);
      }
      function fromFreq(freq2) {
        return (0, import_midi.midiToNoteName)((0, import_midi.freqToMidi)(freq2));
      }
      function fromFreqSharps(freq2) {
        return (0, import_midi.midiToNoteName)((0, import_midi.freqToMidi)(freq2), { sharps: true });
      }
      function fromMidiSharps(midi22) {
        return (0, import_midi.midiToNoteName)(midi22, { sharps: true });
      }
      var distance = import_pitch_distance.distance;
      var transpose = import_pitch_distance.transpose;
      var tr2 = import_pitch_distance.transpose;
      var transposeBy = (interval) => (note) => transpose(note, interval);
      var trBy = transposeBy;
      var transposeFrom = (note) => (interval) => transpose(note, interval);
      var trFrom = transposeFrom;
      function transposeFifths(noteName, fifths) {
        return transpose(noteName, [fifths, 0]);
      }
      var trFifths = transposeFifths;
      function transposeOctaves(noteName, octaves) {
        return transpose(noteName, [0, octaves]);
      }
      var ascending = (a2, b2) => a2.height - b2.height;
      var descending = (a2, b2) => b2.height - a2.height;
      function sortedNames(notes, comparator) {
        comparator = comparator || ascending;
        return onlyNotes(notes).sort(comparator).map(toName);
      }
      function sortedUniqNames(notes) {
        return sortedNames(notes, ascending).filter(
          (n2, i, a2) => i === 0 || n2 !== a2[i - 1]
        );
      }
      var simplify = (noteName) => {
        const note = get(noteName);
        if (note.empty) {
          return "";
        }
        return (0, import_midi.midiToNoteName)(note.midi || note.chroma, {
          sharps: note.alt > 0,
          pitchClass: note.midi === null
        });
      };
      function enharmonic(noteName, destName) {
        const src = get(noteName);
        if (src.empty) {
          return "";
        }
        const dest = get(
          destName || (0, import_midi.midiToNoteName)(src.midi || src.chroma, {
            sharps: src.alt < 0,
            pitchClass: true
          })
        );
        if (dest.empty || dest.chroma !== src.chroma) {
          return "";
        }
        if (src.oct === void 0) {
          return dest.pc;
        }
        const srcChroma = src.chroma - src.alt;
        const destChroma = dest.chroma - dest.alt;
        const destOctOffset = srcChroma > 11 || destChroma < 0 ? -1 : srcChroma < 0 || destChroma > 11 ? 1 : 0;
        const destOct = src.oct + destOctOffset;
        return dest.pc + destOct;
      }
      var index_default = {
        names,
        get,
        name,
        pitchClass,
        accidentals,
        octave,
        midi: midi2,
        ascending,
        descending,
        distance,
        sortedNames,
        sortedUniqNames,
        fromMidi,
        fromMidiSharps,
        freq,
        fromFreq,
        fromFreqSharps,
        chroma,
        transpose,
        tr: tr2,
        transposeBy,
        trBy,
        transposeFrom,
        trFrom,
        transposeFifths,
        transposeOctaves,
        trFifths,
        simplify,
        enharmonic
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/roman-numeral/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist26 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/roman-numeral/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" && !isNaN(pitch2.step) && !isNaN(pitch2.alt) ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/roman-numeral/node_modules/@tonaljs/pitch-interval/dist/index.js
  var require_dist27 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/roman-numeral/node_modules/@tonaljs/pitch-interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_interval_exports = {};
      __export2(pitch_interval_exports, {
        coordToInterval: () => coordToInterval,
        interval: () => interval,
        tokenizeInterval: () => tokenizeInterval
      });
      module.exports = __toCommonJS(pitch_interval_exports);
      var import_pitch = require_dist26();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoInterval = Object.freeze({
        empty: true,
        name: "",
        num: NaN,
        q: "",
        type: "",
        step: NaN,
        alt: NaN,
        dir: NaN,
        simple: NaN,
        semitones: NaN,
        chroma: NaN,
        coord: [],
        oct: NaN
      });
      var INTERVAL_TONAL_REGEX = "([-+]?\\d+)(d{1,4}|m|M|P|A{1,4})";
      var INTERVAL_SHORTHAND_REGEX = "(AA|A|P|M|m|d|dd)([-+]?\\d+)";
      var REGEX = new RegExp(
        "^" + INTERVAL_TONAL_REGEX + "|" + INTERVAL_SHORTHAND_REGEX + "$"
      );
      function tokenizeInterval(str) {
        const m3 = REGEX.exec(`${str}`);
        if (m3 === null) {
          return ["", ""];
        }
        return m3[1] ? [m3[1], m3[2]] : [m3[4], m3[3]];
      }
      var cache = {};
      function interval(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : (0, import_pitch.isPitch)(src) ? interval(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? interval(src.name) : NoInterval;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var TYPES = "PMMPPMM";
      function parse2(str) {
        const tokens = tokenizeInterval(str);
        if (tokens[0] === "") {
          return NoInterval;
        }
        const num = +tokens[0];
        const q6 = tokens[1];
        const step = (Math.abs(num) - 1) % 7;
        const t = TYPES[step];
        if (t === "M" && q6 === "P") {
          return NoInterval;
        }
        const type = t === "M" ? "majorable" : "perfectable";
        const name = "" + num + q6;
        const dir = num < 0 ? -1 : 1;
        const simple = num === 8 || num === -8 ? num : dir * (step + 1);
        const alt = qToAlt(type, q6);
        const oct = Math.floor((Math.abs(num) - 1) / 7);
        const semitones = dir * (SIZES[step] + alt + 12 * oct);
        const chroma = (dir * (SIZES[step] + alt) % 12 + 12) % 12;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct, dir });
        return {
          empty: false,
          name,
          num,
          q: q6,
          step,
          alt,
          dir,
          type,
          simple,
          semitones,
          chroma,
          coord,
          oct
        };
      }
      function coordToInterval(coord, forceDescending) {
        const [f4, o = 0] = coord;
        const isDescending = f4 * 7 + o * 12 < 0;
        const ivl = forceDescending || isDescending ? [-f4, -o, -1] : [f4, o, 1];
        return interval((0, import_pitch.pitch)(ivl));
      }
      function qToAlt(type, q6) {
        return q6 === "M" && type === "majorable" || q6 === "P" && type === "perfectable" ? 0 : q6 === "m" && type === "majorable" ? -1 : /^A+$/.test(q6) ? q6.length : /^d+$/.test(q6) ? -1 * (type === "perfectable" ? q6.length : q6.length + 1) : 0;
      }
      function pitchName(props) {
        const { step, alt, oct = 0, dir } = props;
        if (!dir) {
          return "";
        }
        const calcNum = step + 1 + 7 * oct;
        const num = calcNum === 0 ? step + 1 : calcNum;
        const d2 = dir < 0 ? "-" : "";
        const type = TYPES[step] === "M" ? "majorable" : "perfectable";
        const name = d2 + num + altToQ(type, alt);
        return name;
      }
      function altToQ(type, alt) {
        if (alt === 0) {
          return type === "majorable" ? "M" : "P";
        } else if (alt === -1 && type === "majorable") {
          return "m";
        } else if (alt > 0) {
          return fillStr("A", alt);
        } else {
          return fillStr("d", type === "perfectable" ? alt : alt + 1);
        }
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/roman-numeral/dist/index.js
  var require_dist28 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/roman-numeral/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var roman_numeral_exports = {};
      __export2(roman_numeral_exports, {
        default: () => roman_numeral_default,
        get: () => get,
        names: () => names,
        romanNumeral: () => romanNumeral,
        tokenize: () => tokenize
      });
      module.exports = __toCommonJS(roman_numeral_exports);
      var import_pitch = require_dist26();
      var import_pitch_interval = require_dist27();
      var import_pitch_note = require_dist4();
      var NoRomanNumeral = { empty: true, name: "", chordType: "" };
      var cache = {};
      function get(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : typeof src === "number" ? get(NAMES[src] || "") : (0, import_pitch.isPitch)(src) ? fromPitch(src) : (0, import_pitch.isNamedPitch)(src) ? get(src.name) : NoRomanNumeral;
      }
      var romanNumeral = get;
      function names(major = true) {
        return (major ? NAMES : NAMES_MINOR).slice();
      }
      function fromPitch(pitch) {
        return get((0, import_pitch_note.altToAcc)(pitch.alt) + NAMES[pitch.step]);
      }
      var REGEX = /^(#{1,}|b{1,}|x{1,}|)(IV|I{1,3}|VI{0,2}|iv|i{1,3}|vi{0,2})([^IViv]*)$/;
      function tokenize(str) {
        return REGEX.exec(str) || ["", "", "", ""];
      }
      var ROMANS = "I II III IV V VI VII";
      var NAMES = ROMANS.split(" ");
      var NAMES_MINOR = ROMANS.toLowerCase().split(" ");
      function parse2(src) {
        const [name, acc, roman, chordType] = tokenize(src);
        if (!roman) {
          return NoRomanNumeral;
        }
        const upperRoman = roman.toUpperCase();
        const step = NAMES.indexOf(upperRoman);
        const alt = (0, import_pitch_note.accToAlt)(acc);
        const dir = 1;
        return {
          empty: false,
          name,
          roman,
          interval: (0, import_pitch_interval.interval)({ step, alt, dir }).name,
          acc,
          chordType,
          alt,
          step,
          major: roman === upperRoman,
          oct: 0,
          dir
        };
      }
      var roman_numeral_default = {
        names,
        get,
        // deprecated
        romanNumeral
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/key/dist/index.js
  var require_dist29 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/key/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        default: () => index_default,
        majorKey: () => majorKey,
        majorKeyChords: () => majorKeyChords,
        majorTonicFromKeySignature: () => majorTonicFromKeySignature,
        minorKey: () => minorKey,
        minorKeyChords: () => minorKeyChords
      });
      module.exports = __toCommonJS(index_exports);
      var import_note = require_dist25();
      var import_pitch_note = require_dist4();
      var import_roman_numeral = require_dist28();
      var Empty = Object.freeze([]);
      var NoKey = {
        type: "major",
        tonic: "",
        alteration: 0,
        keySignature: ""
      };
      var NoKeyScale = {
        tonic: "",
        grades: Empty,
        intervals: Empty,
        scale: Empty,
        triads: Empty,
        chords: Empty,
        chordsHarmonicFunction: Empty,
        chordScales: Empty,
        secondaryDominants: Empty,
        secondaryDominantSupertonics: Empty,
        substituteDominantsMinorRelative: Empty,
        substituteDominants: Empty,
        substituteDominantSupertonics: Empty,
        secondaryDominantsMinorRelative: Empty
      };
      var NoMajorKey = {
        ...NoKey,
        ...NoKeyScale,
        type: "major",
        minorRelative: "",
        scale: Empty,
        substituteDominants: Empty,
        secondaryDominantSupertonics: Empty,
        substituteDominantsMinorRelative: Empty
      };
      var NoMinorKey = {
        ...NoKey,
        type: "minor",
        relativeMajor: "",
        natural: NoKeyScale,
        harmonic: NoKeyScale,
        melodic: NoKeyScale
      };
      var mapScaleToType = (scale, list, sep = "") => list.map((type, i) => `${scale[i]}${sep}${type}`);
      function keyScale(grades, triads, chordTypes, harmonicFunctions, chordScales) {
        return (tonic) => {
          const intervals = grades.map((gr2) => (0, import_roman_numeral.get)(gr2).interval || "");
          const scale = intervals.map((interval) => (0, import_note.transpose)(tonic, interval));
          const chords = mapScaleToType(scale, chordTypes);
          const secondaryDominants = scale.map((note2) => (0, import_note.transpose)(note2, "5P")).map(
            (note2) => (
              // A secondary dominant is a V chord which:
              // 1. is not diatonic to the key,
              // 2. it must have a diatonic root.
              scale.includes(note2) && !chords.includes(note2 + "7") ? note2 + "7" : ""
            )
          );
          const secondaryDominantSupertonics = supertonics(
            secondaryDominants,
            triads
          );
          const substituteDominants = secondaryDominants.map((chord) => {
            if (!chord) return "";
            const domRoot = chord.slice(0, -1);
            const subRoot = (0, import_note.transpose)(domRoot, "5d");
            return subRoot + "7";
          });
          const substituteDominantSupertonics = supertonics(
            substituteDominants,
            triads
          );
          return {
            tonic,
            grades,
            intervals,
            scale,
            triads: mapScaleToType(scale, triads),
            chords,
            chordsHarmonicFunction: harmonicFunctions.slice(),
            chordScales: mapScaleToType(scale, chordScales, " "),
            secondaryDominants,
            secondaryDominantSupertonics,
            substituteDominants,
            substituteDominantSupertonics,
            // @deprecated use secondaryDominantsSupertonic
            secondaryDominantsMinorRelative: secondaryDominantSupertonics,
            // @deprecated use secondaryDominantsSupertonic
            substituteDominantsMinorRelative: substituteDominantSupertonics
          };
        };
      }
      var supertonics = (dominants, targetTriads) => {
        return dominants.map((chord, index) => {
          if (!chord) return "";
          const domRoot = chord.slice(0, -1);
          const minorRoot = (0, import_note.transpose)(domRoot, "5P");
          const target = targetTriads[index];
          const isMinor = target.endsWith("m");
          return isMinor ? minorRoot + "m7" : minorRoot + "m7b5";
        });
      };
      var distInFifths = (from, to3) => {
        const f4 = (0, import_pitch_note.note)(from);
        const t = (0, import_pitch_note.note)(to3);
        return f4.empty || t.empty ? 0 : t.coord[0] - f4.coord[0];
      };
      var MajorScale = keyScale(
        "I II III IV V VI VII".split(" "),
        " m m   m dim".split(" "),
        "maj7 m7 m7 maj7 7 m7 m7b5".split(" "),
        "T SD T SD D T D".split(" "),
        "major,dorian,phrygian,lydian,mixolydian,minor,locrian".split(",")
      );
      var NaturalScale = keyScale(
        "I II bIII IV V bVI bVII".split(" "),
        "m dim  m m  ".split(" "),
        "m7 m7b5 maj7 m7 m7 maj7 7".split(" "),
        "T SD T SD D SD SD".split(" "),
        "minor,locrian,major,dorian,phrygian,lydian,mixolydian".split(",")
      );
      var HarmonicScale = keyScale(
        "I II bIII IV V bVI VII".split(" "),
        "m dim aug m   dim".split(" "),
        "mMaj7 m7b5 +maj7 m7 7 maj7 o7".split(" "),
        "T SD T SD D SD D".split(" "),
        "harmonic minor,locrian 6,major augmented,lydian diminished,phrygian dominant,lydian #9,ultralocrian".split(
          ","
        )
      );
      var MelodicScale = keyScale(
        "I II bIII IV V VI VII".split(" "),
        "m m aug   dim dim".split(" "),
        "m6 m7 +maj7 7 7 m7b5 m7b5".split(" "),
        "T SD T SD D  ".split(" "),
        "melodic minor,dorian b2,lydian augmented,lydian dominant,mixolydian b6,locrian #2,altered".split(
          ","
        )
      );
      function majorKey(tonic) {
        const pc3 = (0, import_pitch_note.note)(tonic).pc;
        if (!pc3) return NoMajorKey;
        const keyScale2 = MajorScale(pc3);
        const alteration = distInFifths("C", pc3);
        return {
          ...keyScale2,
          type: "major",
          minorRelative: (0, import_note.transpose)(pc3, "-3m"),
          alteration,
          keySignature: (0, import_pitch_note.altToAcc)(alteration)
        };
      }
      function majorKeyChords(tonic) {
        const key = majorKey(tonic);
        const chords = [];
        keyChordsOf(key, chords);
        return chords;
      }
      function minorKeyChords(tonic) {
        const key = minorKey(tonic);
        const chords = [];
        keyChordsOf(key.natural, chords);
        keyChordsOf(key.harmonic, chords);
        keyChordsOf(key.melodic, chords);
        return chords;
      }
      function keyChordsOf(key, chords) {
        const updateChord = (name, newRole) => {
          if (!name) return;
          let keyChord = chords.find((chord) => chord.name === name);
          if (!keyChord) {
            keyChord = { name, roles: [] };
            chords.push(keyChord);
          }
          if (newRole && !keyChord.roles.includes(newRole)) {
            keyChord.roles.push(newRole);
          }
        };
        key.chords.forEach(
          (chordName, index) => updateChord(chordName, key.chordsHarmonicFunction[index])
        );
        key.secondaryDominants.forEach(
          (chordName, index) => updateChord(chordName, `V/${key.grades[index]}`)
        );
        key.secondaryDominantSupertonics.forEach(
          (chordName, index) => updateChord(chordName, `ii/${key.grades[index]}`)
        );
        key.substituteDominants.forEach(
          (chordName, index) => updateChord(chordName, `subV/${key.grades[index]}`)
        );
        key.substituteDominantSupertonics.forEach(
          (chordName, index) => updateChord(chordName, `subii/${key.grades[index]}`)
        );
      }
      function minorKey(tnc) {
        const pc3 = (0, import_pitch_note.note)(tnc).pc;
        if (!pc3) return NoMinorKey;
        const alteration = distInFifths("C", pc3) - 3;
        return {
          type: "minor",
          tonic: pc3,
          relativeMajor: (0, import_note.transpose)(pc3, "3m"),
          alteration,
          keySignature: (0, import_pitch_note.altToAcc)(alteration),
          natural: NaturalScale(pc3),
          harmonic: HarmonicScale(pc3),
          melodic: MelodicScale(pc3)
        };
      }
      function majorTonicFromKeySignature(sig) {
        if (typeof sig === "number") {
          return (0, import_note.transposeFifths)("C", sig);
        } else if (typeof sig === "string" && /^b+|#+$/.test(sig)) {
          return (0, import_note.transposeFifths)("C", (0, import_pitch_note.accToAlt)(sig));
        }
        return null;
      }
      var index_default = { majorKey, majorTonicFromKeySignature, minorKey };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist30 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" && !isNaN(pitch2.step) && !isNaN(pitch2.alt) ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/node_modules/@tonaljs/pitch-interval/dist/index.js
  var require_dist31 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/node_modules/@tonaljs/pitch-interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_interval_exports = {};
      __export2(pitch_interval_exports, {
        coordToInterval: () => coordToInterval,
        interval: () => interval,
        tokenizeInterval: () => tokenizeInterval
      });
      module.exports = __toCommonJS(pitch_interval_exports);
      var import_pitch = require_dist30();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoInterval = Object.freeze({
        empty: true,
        name: "",
        num: NaN,
        q: "",
        type: "",
        step: NaN,
        alt: NaN,
        dir: NaN,
        simple: NaN,
        semitones: NaN,
        chroma: NaN,
        coord: [],
        oct: NaN
      });
      var INTERVAL_TONAL_REGEX = "([-+]?\\d+)(d{1,4}|m|M|P|A{1,4})";
      var INTERVAL_SHORTHAND_REGEX = "(AA|A|P|M|m|d|dd)([-+]?\\d+)";
      var REGEX = new RegExp(
        "^" + INTERVAL_TONAL_REGEX + "|" + INTERVAL_SHORTHAND_REGEX + "$"
      );
      function tokenizeInterval(str) {
        const m3 = REGEX.exec(`${str}`);
        if (m3 === null) {
          return ["", ""];
        }
        return m3[1] ? [m3[1], m3[2]] : [m3[4], m3[3]];
      }
      var cache = {};
      function interval(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : (0, import_pitch.isPitch)(src) ? interval(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? interval(src.name) : NoInterval;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var TYPES = "PMMPPMM";
      function parse2(str) {
        const tokens = tokenizeInterval(str);
        if (tokens[0] === "") {
          return NoInterval;
        }
        const num = +tokens[0];
        const q6 = tokens[1];
        const step = (Math.abs(num) - 1) % 7;
        const t = TYPES[step];
        if (t === "M" && q6 === "P") {
          return NoInterval;
        }
        const type = t === "M" ? "majorable" : "perfectable";
        const name = "" + num + q6;
        const dir = num < 0 ? -1 : 1;
        const simple = num === 8 || num === -8 ? num : dir * (step + 1);
        const alt = qToAlt(type, q6);
        const oct = Math.floor((Math.abs(num) - 1) / 7);
        const semitones = dir * (SIZES[step] + alt + 12 * oct);
        const chroma = (dir * (SIZES[step] + alt) % 12 + 12) % 12;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct, dir });
        return {
          empty: false,
          name,
          num,
          q: q6,
          step,
          alt,
          dir,
          type,
          simple,
          semitones,
          chroma,
          coord,
          oct
        };
      }
      function coordToInterval(coord, forceDescending) {
        const [f4, o = 0] = coord;
        const isDescending = f4 * 7 + o * 12 < 0;
        const ivl = forceDescending || isDescending ? [-f4, -o, -1] : [f4, o, 1];
        return interval((0, import_pitch.pitch)(ivl));
      }
      function qToAlt(type, q6) {
        return q6 === "M" && type === "majorable" || q6 === "P" && type === "perfectable" ? 0 : q6 === "m" && type === "majorable" ? -1 : /^A+$/.test(q6) ? q6.length : /^d+$/.test(q6) ? -1 * (type === "perfectable" ? q6.length : q6.length + 1) : 0;
      }
      function pitchName(props) {
        const { step, alt, oct = 0, dir } = props;
        if (!dir) {
          return "";
        }
        const calcNum = step + 1 + 7 * oct;
        const num = calcNum === 0 ? step + 1 : calcNum;
        const d2 = dir < 0 ? "-" : "";
        const type = TYPES[step] === "M" ? "majorable" : "perfectable";
        const name = d2 + num + altToQ(type, alt);
        return name;
      }
      function altToQ(type, alt) {
        if (alt === 0) {
          return type === "majorable" ? "M" : "P";
        } else if (alt === -1 && type === "majorable") {
          return "m";
        } else if (alt > 0) {
          return fillStr("A", alt);
        } else {
          return fillStr("d", type === "perfectable" ? alt : alt + 1);
        }
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/node_modules/@tonaljs/interval/dist/index.js
  var require_dist32 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/node_modules/@tonaljs/interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name2 in all)
          __defProp2(target, name2, { get: all[name2], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var interval_exports = {};
      __export2(interval_exports, {
        add: () => add2,
        addTo: () => addTo,
        default: () => interval_default,
        distance: () => distance,
        fromSemitones: () => fromSemitones,
        get: () => get,
        invert: () => invert,
        name: () => name,
        names: () => names,
        num: () => num,
        quality: () => quality,
        semitones: () => semitones,
        simplify: () => simplify,
        subtract: () => subtract,
        transposeFifths: () => transposeFifths
      });
      module.exports = __toCommonJS(interval_exports);
      var import_pitch_distance = require_dist5();
      var import_pitch_interval = require_dist31();
      function names() {
        return "1P 2M 3M 4P 5P 6m 7m".split(" ");
      }
      var get = import_pitch_interval.interval;
      var name = (name2) => (0, import_pitch_interval.interval)(name2).name;
      var semitones = (name2) => (0, import_pitch_interval.interval)(name2).semitones;
      var quality = (name2) => (0, import_pitch_interval.interval)(name2).q;
      var num = (name2) => (0, import_pitch_interval.interval)(name2).num;
      function simplify(name2) {
        const i = (0, import_pitch_interval.interval)(name2);
        return i.empty ? "" : i.simple + i.q;
      }
      function invert(name2) {
        const i = (0, import_pitch_interval.interval)(name2);
        if (i.empty) {
          return "";
        }
        const step = (7 - i.step) % 7;
        const alt = i.type === "perfectable" ? -i.alt : -(i.alt + 1);
        return (0, import_pitch_interval.interval)({ step, alt, oct: i.oct, dir: i.dir }).name;
      }
      var IN = [1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 7];
      var IQ = "P m M m M P d P m M m M".split(" ");
      function fromSemitones(semitones2) {
        const d2 = semitones2 < 0 ? -1 : 1;
        const n2 = Math.abs(semitones2);
        const c3 = n2 % 12;
        const o = Math.floor(n2 / 12);
        return d2 * (IN[c3] + 7 * o) + IQ[c3];
      }
      var distance = import_pitch_distance.distance;
      var add2 = combinator((a2, b2) => [a2[0] + b2[0], a2[1] + b2[1]]);
      var addTo = (interval) => (other) => add2(interval, other);
      var subtract = combinator((a2, b2) => [a2[0] - b2[0], a2[1] - b2[1]]);
      function transposeFifths(interval, fifths) {
        const ivl = get(interval);
        if (ivl.empty) return "";
        const [nFifths, nOcts, dir] = ivl.coord;
        return (0, import_pitch_interval.coordToInterval)([nFifths + fifths, nOcts, dir]).name;
      }
      var interval_default = {
        names,
        get,
        name,
        num,
        semitones,
        quality,
        fromSemitones,
        distance,
        invert,
        simplify,
        add: add2,
        addTo,
        subtract,
        transposeFifths
      };
      function combinator(fn3) {
        return (a2, b2) => {
          const coordA = (0, import_pitch_interval.interval)(a2).coord;
          const coordB = (0, import_pitch_interval.interval)(b2).coord;
          if (coordA && coordB) {
            const coord = fn3(coordA, coordB);
            return (0, import_pitch_interval.coordToInterval)(coord).name;
          }
        };
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/dist/index.js
  var require_dist33 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/mode/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        all: () => all,
        default: () => index_default,
        distance: () => distance,
        entries: () => entries,
        get: () => get,
        mode: () => mode,
        names: () => names,
        notes: () => notes,
        relativeTonic: () => relativeTonic,
        seventhChords: () => seventhChords,
        triads: () => triads
      });
      module.exports = __toCommonJS(index_exports);
      var import_collection = require_dist8();
      var import_interval = require_dist32();
      var import_pcset = require_dist11();
      var import_pitch_distance = require_dist5();
      var import_scale_type = require_dist20();
      var MODES = [
        [0, 2773, 0, "ionian", "", "Maj7", "major"],
        [1, 2902, 2, "dorian", "m", "m7"],
        [2, 3418, 4, "phrygian", "m", "m7"],
        [3, 2741, -1, "lydian", "", "Maj7"],
        [4, 2774, 1, "mixolydian", "", "7"],
        [5, 2906, 3, "aeolian", "m", "m7", "minor"],
        [6, 3434, 5, "locrian", "dim", "m7b5"]
      ];
      var NoMode = {
        ...import_pcset.EmptyPcset,
        name: "",
        alt: 0,
        modeNum: NaN,
        triad: "",
        seventh: "",
        aliases: []
      };
      var modes = MODES.map(toMode);
      var index = {};
      modes.forEach((mode2) => {
        index[mode2.name] = mode2;
        mode2.aliases.forEach((alias) => {
          index[alias] = mode2;
        });
      });
      function get(name) {
        return typeof name === "string" ? index[name.toLowerCase()] || NoMode : name && name.name ? get(name.name) : NoMode;
      }
      var mode = get;
      function all() {
        return modes.slice();
      }
      var entries = all;
      function names() {
        return modes.map((mode2) => mode2.name);
      }
      function toMode(mode2) {
        const [modeNum, setNum, alt, name, triad, seventh, alias] = mode2;
        const aliases = alias ? [alias] : [];
        const chroma = Number(setNum).toString(2);
        const intervals = (0, import_scale_type.get)(name).intervals;
        return {
          empty: false,
          intervals,
          modeNum,
          chroma,
          normalized: chroma,
          name,
          setNum,
          alt,
          triad,
          seventh,
          aliases
        };
      }
      function notes(modeName, tonic) {
        return get(modeName).intervals.map((ivl) => (0, import_pitch_distance.transpose)(tonic, ivl));
      }
      function chords(chords2) {
        return (modeName, tonic) => {
          const mode2 = get(modeName);
          if (mode2.empty) return [];
          const triads2 = (0, import_collection.rotate)(mode2.modeNum, chords2);
          const tonics = mode2.intervals.map((i) => (0, import_pitch_distance.transpose)(tonic, i));
          return triads2.map((triad, i) => tonics[i] + triad);
        };
      }
      var triads = chords(MODES.map((x2) => x2[4]));
      var seventhChords = chords(MODES.map((x2) => x2[5]));
      function distance(destination, source) {
        const from = get(source);
        const to3 = get(destination);
        if (from.empty || to3.empty) return "";
        return (0, import_interval.simplify)((0, import_interval.transposeFifths)("1P", to3.alt - from.alt));
      }
      function relativeTonic(destination, source, tonic) {
        return (0, import_pitch_distance.transpose)(tonic, distance(destination, source));
      }
      var index_default = {
        get,
        names,
        all,
        distance,
        relativeTonic,
        notes,
        triads,
        seventhChords,
        // deprecated
        entries,
        mode
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/chord-type/dist/index.js
  var require_dist34 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/chord-type/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var chord_type_exports = {};
      __export2(chord_type_exports, {
        add: () => add2,
        addAlias: () => addAlias,
        all: () => all,
        chordType: () => chordType,
        default: () => chord_type_default,
        entries: () => entries,
        get: () => get,
        keys: () => keys,
        names: () => names,
        removeAll: () => removeAll,
        symbols: () => symbols
      });
      module.exports = __toCommonJS(chord_type_exports);
      var import_pcset = require_dist11();
      var CHORDS = [
        // ==Major==
        ["1P 3M 5P", "major", "M ^  maj"],
        ["1P 3M 5P 7M", "major seventh", "maj7 \u0394 ma7 M7 Maj7 ^7"],
        ["1P 3M 5P 7M 9M", "major ninth", "maj9 \u03949 ^9"],
        ["1P 3M 5P 7M 9M 13M", "major thirteenth", "maj13 Maj13 ^13"],
        ["1P 3M 5P 6M", "sixth", "6 add6 add13 M6"],
        ["1P 3M 5P 6M 9M", "sixth added ninth", "6add9 6/9 69 M69"],
        ["1P 3M 6m 7M", "major seventh flat sixth", "M7b6 ^7b6"],
        [
          "1P 3M 5P 7M 11A",
          "major seventh sharp eleventh",
          "maj#4 \u0394#4 \u0394#11 M7#11 ^7#11 maj7#11"
        ],
        // ==Minor==
        // '''Normal'''
        ["1P 3m 5P", "minor", "m min -"],
        ["1P 3m 5P 7m", "minor seventh", "m7 min7 mi7 -7"],
        [
          "1P 3m 5P 7M",
          "minor/major seventh",
          "m/ma7 m/maj7 mM7 mMaj7 m/M7 -\u03947 m\u0394 -^7 -maj7"
        ],
        ["1P 3m 5P 6M", "minor sixth", "m6 -6"],
        ["1P 3m 5P 7m 9M", "minor ninth", "m9 -9"],
        ["1P 3m 5P 7M 9M", "minor/major ninth", "mM9 mMaj9 -^9"],
        ["1P 3m 5P 7m 9M 11P", "minor eleventh", "m11 -11"],
        ["1P 3m 5P 7m 9M 13M", "minor thirteenth", "m13 -13"],
        // '''Diminished'''
        ["1P 3m 5d", "diminished", "dim \xB0 o"],
        ["1P 3m 5d 7d", "diminished seventh", "dim7 \xB07 o7"],
        ["1P 3m 5d 7m", "half-diminished", "m7b5 \xF8 -7b5 h7 h"],
        // ==Dominant/Seventh==
        // '''Normal'''
        ["1P 3M 5P 7m", "dominant seventh", "7 dom"],
        ["1P 3M 5P 7m 9M", "dominant ninth", "9"],
        ["1P 3M 5P 7m 9M 13M", "dominant thirteenth", "13"],
        ["1P 3M 5P 7m 11A", "lydian dominant seventh", "7#11 7#4"],
        // '''Altered'''
        ["1P 3M 5P 7m 9m", "dominant flat ninth", "7b9"],
        ["1P 3M 5P 7m 9A", "dominant sharp ninth", "7#9"],
        ["1P 3M 7m 9m", "altered", "alt7"],
        // '''Suspended'''
        ["1P 4P 5P", "suspended fourth", "sus4 sus"],
        ["1P 2M 5P", "suspended second", "sus2"],
        ["1P 4P 5P 7m", "suspended fourth seventh", "7sus4 7sus"],
        ["1P 5P 7m 9M 11P", "eleventh", "11"],
        [
          "1P 4P 5P 7m 9m",
          "suspended fourth flat ninth",
          "b9sus phryg 7b9sus 7b9sus4"
        ],
        // ==Other==
        ["1P 5P", "fifth", "5"],
        ["1P 3M 5A", "augmented", "aug + +5 ^#5"],
        ["1P 3m 5A", "minor augmented", "m#5 -#5 m+"],
        ["1P 3M 5A 7M", "augmented seventh", "maj7#5 maj7+5 +maj7 ^7#5"],
        [
          "1P 3M 5P 7M 9M 11A",
          "major sharp eleventh (lydian)",
          "maj9#11 \u03949#11 ^9#11"
        ],
        // ==Legacy==
        ["1P 2M 4P 5P", "", "sus24 sus4add9"],
        ["1P 3M 5A 7M 9M", "", "maj9#5 Maj9#5"],
        ["1P 3M 5A 7m", "", "7#5 +7 7+ 7aug aug7"],
        ["1P 3M 5A 7m 9A", "", "7#5#9 7#9#5 7alt"],
        ["1P 3M 5A 7m 9M", "", "9#5 9+"],
        ["1P 3M 5A 7m 9M 11A", "", "9#5#11"],
        ["1P 3M 5A 7m 9m", "", "7#5b9 7b9#5"],
        ["1P 3M 5A 7m 9m 11A", "", "7#5b9#11"],
        ["1P 3M 5A 9A", "", "+add#9"],
        ["1P 3M 5A 9M", "", "M#5add9 +add9"],
        ["1P 3M 5P 6M 11A", "", "M6#11 M6b5 6#11 6b5"],
        ["1P 3M 5P 6M 7M 9M", "", "M7add13"],
        ["1P 3M 5P 6M 9M 11A", "", "69#11"],
        ["1P 3m 5P 6M 9M", "", "m69 -69"],
        ["1P 3M 5P 6m 7m", "", "7b6"],
        ["1P 3M 5P 7M 9A 11A", "", "maj7#9#11"],
        ["1P 3M 5P 7M 9M 11A 13M", "", "M13#11 maj13#11 M13+4 M13#4"],
        ["1P 3M 5P 7M 9m", "", "M7b9"],
        ["1P 3M 5P 7m 11A 13m", "", "7#11b13 7b5b13"],
        ["1P 3M 5P 7m 13M", "", "7add6 67 7add13"],
        ["1P 3M 5P 7m 9A 11A", "", "7#9#11 7b5#9 7#9b5"],
        ["1P 3M 5P 7m 9A 11A 13M", "", "13#9#11"],
        ["1P 3M 5P 7m 9A 11A 13m", "", "7#9#11b13"],
        ["1P 3M 5P 7m 9A 13M", "", "13#9"],
        ["1P 3M 5P 7m 9A 13m", "", "7#9b13"],
        ["1P 3M 5P 7m 9M 11A", "", "9#11 9+4 9#4"],
        ["1P 3M 5P 7m 9M 11A 13M", "", "13#11 13+4 13#4"],
        ["1P 3M 5P 7m 9M 11A 13m", "", "9#11b13 9b5b13"],
        ["1P 3M 5P 7m 9m 11A", "", "7b9#11 7b5b9 7b9b5"],
        ["1P 3M 5P 7m 9m 11A 13M", "", "13b9#11"],
        ["1P 3M 5P 7m 9m 11A 13m", "", "7b9b13#11 7b9#11b13 7b5b9b13"],
        ["1P 3M 5P 7m 9m 13M", "", "13b9"],
        ["1P 3M 5P 7m 9m 13m", "", "7b9b13"],
        ["1P 3M 5P 7m 9m 9A", "", "7b9#9"],
        ["1P 3M 5P 9M", "", "Madd9 2 add9 add2"],
        ["1P 3M 5P 9m", "", "Maddb9"],
        ["1P 3M 5d", "", "Mb5"],
        ["1P 3M 5d 6M 7m 9M", "", "13b5"],
        ["1P 3M 5d 7M", "", "M7b5"],
        ["1P 3M 5d 7M 9M", "", "M9b5"],
        ["1P 3M 5d 7m", "", "7b5"],
        ["1P 3M 5d 7m 9M", "", "9b5"],
        ["1P 3M 7m", "", "7no5"],
        ["1P 3M 7m 13m", "", "7b13"],
        ["1P 3M 7m 9M", "", "9no5"],
        ["1P 3M 7m 9M 13M", "", "13no5"],
        ["1P 3M 7m 9M 13m", "", "9b13"],
        ["1P 3m 4P 5P", "", "madd4"],
        ["1P 3m 5P 6m 7M", "", "mMaj7b6"],
        ["1P 3m 5P 6m 7M 9M", "", "mMaj9b6"],
        ["1P 3m 5P 7m 11P", "", "m7add11 m7add4"],
        ["1P 3m 5P 9M", "", "madd9"],
        ["1P 3m 5d 6M 7M", "", "o7M7"],
        ["1P 3m 5d 7M", "", "oM7"],
        ["1P 3m 6m 7M", "", "mb6M7"],
        ["1P 3m 6m 7m", "", "m7#5"],
        ["1P 3m 6m 7m 9M", "", "m9#5"],
        ["1P 3m 5A 7m 9M 11P", "", "m11A"],
        ["1P 3m 6m 9m", "", "mb6b9"],
        ["1P 2M 3m 5d 7m", "", "m9b5"],
        ["1P 4P 5A 7M", "", "M7#5sus4"],
        ["1P 4P 5A 7M 9M", "", "M9#5sus4"],
        ["1P 4P 5A 7m", "", "7#5sus4"],
        ["1P 4P 5P 7M", "", "M7sus4"],
        ["1P 4P 5P 7M 9M", "", "M9sus4"],
        ["1P 4P 5P 7m 9M", "", "9sus4 9sus"],
        ["1P 4P 5P 7m 9M 13M", "", "13sus4 13sus"],
        ["1P 4P 5P 7m 9m 13m", "", "7sus4b9b13 7b9b13sus4"],
        ["1P 4P 7m 10m", "", "4 quartal"],
        ["1P 5P 7m 9m 11P", "", "11b9"]
      ];
      var data_default = CHORDS;
      var NoChordType = {
        ...import_pcset.EmptyPcset,
        name: "",
        quality: "Unknown",
        intervals: [],
        aliases: []
      };
      var dictionary = [];
      var index = {};
      function get(type) {
        return index[type] || NoChordType;
      }
      var chordType = get;
      function names() {
        return dictionary.map((chord) => chord.name).filter((x2) => x2);
      }
      function symbols() {
        return dictionary.map((chord) => chord.aliases[0]).filter((x2) => x2);
      }
      function keys() {
        return Object.keys(index);
      }
      function all() {
        return dictionary.slice();
      }
      var entries = all;
      function removeAll() {
        dictionary = [];
        index = {};
      }
      function add2(intervals, aliases, fullName) {
        const quality = getQuality(intervals);
        const chord = {
          ...(0, import_pcset.get)(intervals),
          name: fullName || "",
          quality,
          intervals,
          aliases
        };
        dictionary.push(chord);
        if (chord.name) {
          index[chord.name] = chord;
        }
        index[chord.setNum] = chord;
        index[chord.chroma] = chord;
        chord.aliases.forEach((alias) => addAlias(chord, alias));
      }
      function addAlias(chord, alias) {
        index[alias] = chord;
      }
      function getQuality(intervals) {
        const has = (interval) => intervals.indexOf(interval) !== -1;
        return has("5A") ? "Augmented" : has("3M") ? "Major" : has("5d") ? "Diminished" : has("3m") ? "Minor" : "Unknown";
      }
      data_default.forEach(
        ([ivls, fullName, names2]) => add2(ivls.split(" "), names2.split(" "), fullName)
      );
      dictionary.sort((a2, b2) => a2.setNum - b2.setNum);
      var chord_type_default = {
        names,
        symbols,
        get,
        all,
        add: add2,
        removeAll,
        keys,
        // deprecated
        entries,
        chordType
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/pitch/dist/index.js
  var require_dist35 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/pitch/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_exports = {};
      __export2(pitch_exports, {
        chroma: () => chroma,
        coordinates: () => coordinates,
        height: () => height,
        isNamedPitch: () => isNamedPitch,
        isPitch: () => isPitch,
        midi: () => midi2,
        pitch: () => pitch
      });
      module.exports = __toCommonJS(pitch_exports);
      function isNamedPitch(src) {
        return src !== null && typeof src === "object" && "name" in src && typeof src.name === "string" ? true : false;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var chroma = ({ step, alt }) => (SIZES[step] + alt + 120) % 12;
      var height = ({ step, alt, oct, dir = 1 }) => dir * (SIZES[step] + alt + 12 * (oct === void 0 ? -100 : oct));
      var midi2 = (pitch2) => {
        const h = height(pitch2);
        return pitch2.oct !== void 0 && h >= -12 && h <= 115 ? h + 12 : null;
      };
      function isPitch(pitch2) {
        return pitch2 !== null && typeof pitch2 === "object" && "step" in pitch2 && typeof pitch2.step === "number" && "alt" in pitch2 && typeof pitch2.alt === "number" && !isNaN(pitch2.step) && !isNaN(pitch2.alt) ? true : false;
      }
      var FIFTHS = [0, 2, 4, -1, 1, 3, 5];
      var STEPS_TO_OCTS = FIFTHS.map(
        (fifths) => Math.floor(fifths * 7 / 12)
      );
      function coordinates(pitch2) {
        const { step, alt, oct, dir = 1 } = pitch2;
        const f4 = FIFTHS[step] + 7 * alt;
        if (oct === void 0) {
          return [dir * f4];
        }
        const o = oct - STEPS_TO_OCTS[step] - 4 * alt;
        return [dir * f4, dir * o];
      }
      var FIFTHS_TO_STEPS = [3, 0, 4, 1, 5, 2, 6];
      function pitch(coord) {
        const [f4, o, dir] = coord;
        const step = FIFTHS_TO_STEPS[unaltered(f4)];
        const alt = Math.floor((f4 + 1) / 7);
        if (o === void 0) {
          return { step, alt, dir };
        }
        const oct = o + 4 * alt + STEPS_TO_OCTS[step];
        return { step, alt, oct, dir };
      }
      function unaltered(f4) {
        const i = (f4 + 1) % 7;
        return i < 0 ? 7 + i : i;
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/pitch-interval/dist/index.js
  var require_dist36 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/pitch-interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var pitch_interval_exports = {};
      __export2(pitch_interval_exports, {
        coordToInterval: () => coordToInterval,
        interval: () => interval,
        tokenizeInterval: () => tokenizeInterval
      });
      module.exports = __toCommonJS(pitch_interval_exports);
      var import_pitch = require_dist35();
      var fillStr = (s2, n2) => Array(Math.abs(n2) + 1).join(s2);
      var NoInterval = Object.freeze({
        empty: true,
        name: "",
        num: NaN,
        q: "",
        type: "",
        step: NaN,
        alt: NaN,
        dir: NaN,
        simple: NaN,
        semitones: NaN,
        chroma: NaN,
        coord: [],
        oct: NaN
      });
      var INTERVAL_TONAL_REGEX = "([-+]?\\d+)(d{1,4}|m|M|P|A{1,4})";
      var INTERVAL_SHORTHAND_REGEX = "(AA|A|P|M|m|d|dd)([-+]?\\d+)";
      var REGEX = new RegExp(
        "^" + INTERVAL_TONAL_REGEX + "|" + INTERVAL_SHORTHAND_REGEX + "$"
      );
      function tokenizeInterval(str) {
        const m3 = REGEX.exec(`${str}`);
        if (m3 === null) {
          return ["", ""];
        }
        return m3[1] ? [m3[1], m3[2]] : [m3[4], m3[3]];
      }
      var cache = {};
      function interval(src) {
        return typeof src === "string" ? cache[src] || (cache[src] = parse2(src)) : (0, import_pitch.isPitch)(src) ? interval(pitchName(src)) : (0, import_pitch.isNamedPitch)(src) ? interval(src.name) : NoInterval;
      }
      var SIZES = [0, 2, 4, 5, 7, 9, 11];
      var TYPES = "PMMPPMM";
      function parse2(str) {
        const tokens = tokenizeInterval(str);
        if (tokens[0] === "") {
          return NoInterval;
        }
        const num = +tokens[0];
        const q6 = tokens[1];
        const step = (Math.abs(num) - 1) % 7;
        const t = TYPES[step];
        if (t === "M" && q6 === "P") {
          return NoInterval;
        }
        const type = t === "M" ? "majorable" : "perfectable";
        const name = "" + num + q6;
        const dir = num < 0 ? -1 : 1;
        const simple = num === 8 || num === -8 ? num : dir * (step + 1);
        const alt = qToAlt(type, q6);
        const oct = Math.floor((Math.abs(num) - 1) / 7);
        const semitones = dir * (SIZES[step] + alt + 12 * oct);
        const chroma = (dir * (SIZES[step] + alt) % 12 + 12) % 12;
        const coord = (0, import_pitch.coordinates)({ step, alt, oct, dir });
        return {
          empty: false,
          name,
          num,
          q: q6,
          step,
          alt,
          dir,
          type,
          simple,
          semitones,
          chroma,
          coord,
          oct
        };
      }
      function coordToInterval(coord, forceDescending) {
        const [f4, o = 0] = coord;
        const isDescending = f4 * 7 + o * 12 < 0;
        const ivl = forceDescending || isDescending ? [-f4, -o, -1] : [f4, o, 1];
        return interval((0, import_pitch.pitch)(ivl));
      }
      function qToAlt(type, q6) {
        return q6 === "M" && type === "majorable" || q6 === "P" && type === "perfectable" ? 0 : q6 === "m" && type === "majorable" ? -1 : /^A+$/.test(q6) ? q6.length : /^d+$/.test(q6) ? -1 * (type === "perfectable" ? q6.length : q6.length + 1) : 0;
      }
      function pitchName(props) {
        const { step, alt, oct = 0, dir } = props;
        if (!dir) {
          return "";
        }
        const calcNum = step + 1 + 7 * oct;
        const num = calcNum === 0 ? step + 1 : calcNum;
        const d2 = dir < 0 ? "-" : "";
        const type = TYPES[step] === "M" ? "majorable" : "perfectable";
        const name = d2 + num + altToQ(type, alt);
        return name;
      }
      function altToQ(type, alt) {
        if (alt === 0) {
          return type === "majorable" ? "M" : "P";
        } else if (alt === -1 && type === "majorable") {
          return "m";
        } else if (alt > 0) {
          return fillStr("A", alt);
        } else {
          return fillStr("d", type === "perfectable" ? alt : alt + 1);
        }
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/interval/dist/index.js
  var require_dist37 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/interval/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name2 in all)
          __defProp2(target, name2, { get: all[name2], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var interval_exports = {};
      __export2(interval_exports, {
        add: () => add2,
        addTo: () => addTo,
        default: () => interval_default,
        distance: () => distance,
        fromSemitones: () => fromSemitones,
        get: () => get,
        invert: () => invert,
        name: () => name,
        names: () => names,
        num: () => num,
        quality: () => quality,
        semitones: () => semitones,
        simplify: () => simplify,
        subtract: () => subtract,
        transposeFifths: () => transposeFifths
      });
      module.exports = __toCommonJS(interval_exports);
      var import_pitch_distance = require_dist5();
      var import_pitch_interval = require_dist36();
      function names() {
        return "1P 2M 3M 4P 5P 6m 7m".split(" ");
      }
      var get = import_pitch_interval.interval;
      var name = (name2) => (0, import_pitch_interval.interval)(name2).name;
      var semitones = (name2) => (0, import_pitch_interval.interval)(name2).semitones;
      var quality = (name2) => (0, import_pitch_interval.interval)(name2).q;
      var num = (name2) => (0, import_pitch_interval.interval)(name2).num;
      function simplify(name2) {
        const i = (0, import_pitch_interval.interval)(name2);
        return i.empty ? "" : i.simple + i.q;
      }
      function invert(name2) {
        const i = (0, import_pitch_interval.interval)(name2);
        if (i.empty) {
          return "";
        }
        const step = (7 - i.step) % 7;
        const alt = i.type === "perfectable" ? -i.alt : -(i.alt + 1);
        return (0, import_pitch_interval.interval)({ step, alt, oct: i.oct, dir: i.dir }).name;
      }
      var IN = [1, 2, 2, 3, 3, 4, 5, 5, 6, 6, 7, 7];
      var IQ = "P m M m M P d P m M m M".split(" ");
      function fromSemitones(semitones2) {
        const d2 = semitones2 < 0 ? -1 : 1;
        const n2 = Math.abs(semitones2);
        const c3 = n2 % 12;
        const o = Math.floor(n2 / 12);
        return d2 * (IN[c3] + 7 * o) + IQ[c3];
      }
      var distance = import_pitch_distance.distance;
      var add2 = combinator((a2, b2) => [a2[0] + b2[0], a2[1] + b2[1]]);
      var addTo = (interval) => (other) => add2(interval, other);
      var subtract = combinator((a2, b2) => [a2[0] - b2[0], a2[1] - b2[1]]);
      function transposeFifths(interval, fifths) {
        const ivl = get(interval);
        if (ivl.empty) return "";
        const [nFifths, nOcts, dir] = ivl.coord;
        return (0, import_pitch_interval.coordToInterval)([nFifths + fifths, nOcts, dir]).name;
      }
      var interval_default = {
        names,
        get,
        name,
        num,
        semitones,
        quality,
        fromSemitones,
        distance,
        invert,
        simplify,
        add: add2,
        addTo,
        subtract,
        transposeFifths
      };
      function combinator(fn3) {
        return (a2, b2) => {
          const coordA = (0, import_pitch_interval.interval)(a2).coord;
          const coordB = (0, import_pitch_interval.interval)(b2).coord;
          if (coordA && coordB) {
            const coord = fn3(coordA, coordB);
            return (0, import_pitch_interval.coordToInterval)(coord).name;
          }
        };
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/chord/dist/index.js
  var require_dist38 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/node_modules/@tonaljs/chord/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        chord: () => chord,
        chordScales: () => chordScales,
        default: () => index_default,
        degrees: () => degrees,
        detect: () => import_chord_detect2.detect,
        extended: () => extended,
        get: () => get,
        getChord: () => getChord,
        notes: () => notes,
        reduced: () => reduced,
        steps: () => steps,
        tokenize: () => tokenize,
        transpose: () => transpose
      });
      module.exports = __toCommonJS(index_exports);
      var import_chord_detect = require_dist13();
      var import_chord_type = require_dist34();
      var import_interval = require_dist37();
      var import_pcset = require_dist11();
      var import_pitch_distance = require_dist5();
      var import_pitch_note = require_dist4();
      var import_scale_type = require_dist20();
      var import_chord_detect2 = require_dist13();
      var NoChord = {
        empty: true,
        name: "",
        symbol: "",
        root: "",
        bass: "",
        rootDegree: 0,
        type: "",
        tonic: null,
        setNum: NaN,
        quality: "Unknown",
        chroma: "",
        normalized: "",
        aliases: [],
        notes: [],
        intervals: []
      };
      function tokenize(name) {
        const [letter, acc, oct, type] = (0, import_pitch_note.tokenizeNote)(name);
        if (letter === "") {
          return tokenizeBass("", name);
        } else if (letter === "A" && type === "ug") {
          return tokenizeBass("", "aug");
        } else {
          return tokenizeBass(letter + acc, oct + type);
        }
      }
      function tokenizeBass(note2, chord2) {
        const split = chord2.split("/");
        if (split.length === 1) {
          return [note2, split[0], ""];
        }
        const [letter, acc, oct, type] = (0, import_pitch_note.tokenizeNote)(split[1]);
        if (letter !== "" && oct === "" && type === "") {
          return [note2, split[0], letter + acc];
        } else {
          return [note2, chord2, ""];
        }
      }
      function get(src) {
        if (Array.isArray(src)) {
          return getChord(src[1] || "", src[0], src[2]);
        } else if (src === "") {
          return NoChord;
        } else {
          const [tonic, type, bass] = tokenize(src);
          const chord2 = getChord(type, tonic, bass);
          return chord2.empty ? getChord(src) : chord2;
        }
      }
      function getChord(typeName, optionalTonic, optionalBass) {
        const type = (0, import_chord_type.get)(typeName);
        const tonic = (0, import_pitch_note.note)(optionalTonic || "");
        const bass = (0, import_pitch_note.note)(optionalBass || "");
        if (type.empty || optionalTonic && tonic.empty || optionalBass && bass.empty) {
          return NoChord;
        }
        const bassInterval = (0, import_pitch_distance.distance)(tonic.pc, bass.pc);
        const bassIndex = type.intervals.indexOf(bassInterval);
        const hasRoot = bassIndex >= 0;
        const root = hasRoot ? bass : (0, import_pitch_note.note)("");
        const rootDegree = bassIndex === -1 ? NaN : bassIndex + 1;
        const hasBass = bass.pc && bass.pc !== tonic.pc;
        const intervals = Array.from(type.intervals);
        if (hasRoot) {
          for (let i = 1; i < rootDegree; i++) {
            const num = intervals[0][0];
            const quality = intervals[0][1];
            const newNum = parseInt(num, 10) + 7;
            intervals.push(`${newNum}${quality}`);
            intervals.shift();
          }
        } else if (hasBass) {
          const ivl = (0, import_interval.subtract)((0, import_pitch_distance.distance)(tonic.pc, bass.pc), "8P");
          if (ivl) intervals.unshift(ivl);
        }
        const notes2 = tonic.empty ? [] : intervals.map((i) => (0, import_pitch_distance.transpose)(tonic.pc, i));
        typeName = type.aliases.indexOf(typeName) !== -1 ? typeName : type.aliases[0];
        const symbol = `${tonic.empty ? "" : tonic.pc}${typeName}${hasRoot && rootDegree > 1 ? "/" + root.pc : hasBass ? "/" + bass.pc : ""}`;
        const name = `${optionalTonic ? tonic.pc + " " : ""}${type.name}${hasRoot && rootDegree > 1 ? " over " + root.pc : hasBass ? " over " + bass.pc : ""}`;
        return {
          ...type,
          name,
          symbol,
          tonic: tonic.pc,
          type: type.name,
          root: root.pc,
          bass: hasBass ? bass.pc : "",
          intervals,
          rootDegree,
          notes: notes2
        };
      }
      var chord = get;
      function transpose(chordName, interval) {
        const [tonic, type, bass] = tokenize(chordName);
        if (!tonic) {
          return chordName;
        }
        const tr2 = (0, import_pitch_distance.transpose)(bass, interval);
        const slash = tr2 ? "/" + tr2 : "";
        return (0, import_pitch_distance.transpose)(tonic, interval) + type + slash;
      }
      function chordScales(name) {
        const s2 = get(name);
        const isChordIncluded = (0, import_pcset.isSupersetOf)(s2.chroma);
        return (0, import_scale_type.all)().filter((scale) => isChordIncluded(scale.chroma)).map((scale) => scale.name);
      }
      function extended(chordName) {
        const s2 = get(chordName);
        const isSuperset = (0, import_pcset.isSupersetOf)(s2.chroma);
        return (0, import_chord_type.all)().filter((chord2) => isSuperset(chord2.chroma)).map((chord2) => s2.tonic + chord2.aliases[0]);
      }
      function reduced(chordName) {
        const s2 = get(chordName);
        const isSubset = (0, import_pcset.isSubsetOf)(s2.chroma);
        return (0, import_chord_type.all)().filter((chord2) => isSubset(chord2.chroma)).map((chord2) => s2.tonic + chord2.aliases[0]);
      }
      function notes(chordName, tonic) {
        const chord2 = get(chordName);
        const note2 = tonic || chord2.tonic;
        if (!note2 || chord2.empty) return [];
        return chord2.intervals.map((ivl) => (0, import_pitch_distance.transpose)(note2, ivl));
      }
      function degrees(chordName, tonic) {
        const chord2 = get(chordName);
        const note2 = tonic || chord2.tonic;
        const transpose2 = (0, import_pitch_distance.tonicIntervalsTransposer)(chord2.intervals, note2);
        return (degree) => degree ? transpose2(degree > 0 ? degree - 1 : degree) : "";
      }
      function steps(chordName, tonic) {
        const chord2 = get(chordName);
        const note2 = tonic || chord2.tonic;
        return (0, import_pitch_distance.tonicIntervalsTransposer)(chord2.intervals, note2);
      }
      var index_default = {
        getChord,
        get,
        detect: import_chord_detect.detect,
        chordScales,
        extended,
        reduced,
        tokenize,
        transpose,
        degrees,
        steps,
        notes,
        chord
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/dist/index.js
  var require_dist39 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/progression/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        default: () => index_default,
        fromRomanNumerals: () => fromRomanNumerals,
        toRomanNumerals: () => toRomanNumerals
      });
      module.exports = __toCommonJS(index_exports);
      var import_chord = require_dist38();
      var import_pitch_distance = require_dist5();
      var import_pitch_interval = require_dist36();
      var import_roman_numeral = require_dist28();
      function fromRomanNumerals(tonic, chords) {
        const romanNumerals = chords.map(import_roman_numeral.get);
        return romanNumerals.map(
          (rn2) => (0, import_pitch_distance.transpose)(tonic, (0, import_pitch_interval.interval)(rn2)) + rn2.chordType
        );
      }
      function toRomanNumerals(tonic, chords) {
        return chords.map((chord) => {
          const [note, chordType] = (0, import_chord.tokenize)(chord);
          const intervalName = (0, import_pitch_distance.distance)(tonic, note);
          const roman = (0, import_roman_numeral.get)((0, import_pitch_interval.interval)(intervalName));
          return roman.name + chordType;
        });
      }
      var index_default = { fromRomanNumerals, toRomanNumerals };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/range/dist/index.js
  var require_dist40 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/range/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        chromatic: () => chromatic,
        default: () => index_default,
        numeric: () => numeric
      });
      module.exports = __toCommonJS(index_exports);
      var import_collection = require_dist8();
      var import_midi = require_dist24();
      function numeric(notes) {
        const midi2 = (0, import_collection.compact)(
          notes.map((note) => typeof note === "number" ? note : (0, import_midi.toMidi)(note))
        );
        if (!notes.length || midi2.length !== notes.length) {
          return [];
        }
        return midi2.reduce(
          (result, note) => {
            const last = result[result.length - 1];
            return result.concat((0, import_collection.range)(last, note).slice(1));
          },
          [midi2[0]]
        );
      }
      function chromatic(notes, options) {
        return numeric(notes).map((midi2) => (0, import_midi.midiToNoteName)(midi2, options));
      }
      var index_default = { numeric, chromatic };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/scale/node_modules/@tonaljs/chord-type/dist/index.js
  var require_dist41 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/scale/node_modules/@tonaljs/chord-type/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var chord_type_exports = {};
      __export2(chord_type_exports, {
        add: () => add2,
        addAlias: () => addAlias,
        all: () => all,
        chordType: () => chordType,
        default: () => chord_type_default,
        entries: () => entries,
        get: () => get,
        keys: () => keys,
        names: () => names,
        removeAll: () => removeAll,
        symbols: () => symbols
      });
      module.exports = __toCommonJS(chord_type_exports);
      var import_pcset = require_dist11();
      var CHORDS = [
        // ==Major==
        ["1P 3M 5P", "major", "M ^  maj"],
        ["1P 3M 5P 7M", "major seventh", "maj7 \u0394 ma7 M7 Maj7 ^7"],
        ["1P 3M 5P 7M 9M", "major ninth", "maj9 \u03949 ^9"],
        ["1P 3M 5P 7M 9M 13M", "major thirteenth", "maj13 Maj13 ^13"],
        ["1P 3M 5P 6M", "sixth", "6 add6 add13 M6"],
        ["1P 3M 5P 6M 9M", "sixth added ninth", "6add9 6/9 69 M69"],
        ["1P 3M 6m 7M", "major seventh flat sixth", "M7b6 ^7b6"],
        [
          "1P 3M 5P 7M 11A",
          "major seventh sharp eleventh",
          "maj#4 \u0394#4 \u0394#11 M7#11 ^7#11 maj7#11"
        ],
        // ==Minor==
        // '''Normal'''
        ["1P 3m 5P", "minor", "m min -"],
        ["1P 3m 5P 7m", "minor seventh", "m7 min7 mi7 -7"],
        [
          "1P 3m 5P 7M",
          "minor/major seventh",
          "m/ma7 m/maj7 mM7 mMaj7 m/M7 -\u03947 m\u0394 -^7 -maj7"
        ],
        ["1P 3m 5P 6M", "minor sixth", "m6 -6"],
        ["1P 3m 5P 7m 9M", "minor ninth", "m9 -9"],
        ["1P 3m 5P 7M 9M", "minor/major ninth", "mM9 mMaj9 -^9"],
        ["1P 3m 5P 7m 9M 11P", "minor eleventh", "m11 -11"],
        ["1P 3m 5P 7m 9M 13M", "minor thirteenth", "m13 -13"],
        // '''Diminished'''
        ["1P 3m 5d", "diminished", "dim \xB0 o"],
        ["1P 3m 5d 7d", "diminished seventh", "dim7 \xB07 o7"],
        ["1P 3m 5d 7m", "half-diminished", "m7b5 \xF8 -7b5 h7 h"],
        // ==Dominant/Seventh==
        // '''Normal'''
        ["1P 3M 5P 7m", "dominant seventh", "7 dom"],
        ["1P 3M 5P 7m 9M", "dominant ninth", "9"],
        ["1P 3M 5P 7m 9M 13M", "dominant thirteenth", "13"],
        ["1P 3M 5P 7m 11A", "lydian dominant seventh", "7#11 7#4"],
        // '''Altered'''
        ["1P 3M 5P 7m 9m", "dominant flat ninth", "7b9"],
        ["1P 3M 5P 7m 9A", "dominant sharp ninth", "7#9"],
        ["1P 3M 7m 9m", "altered", "alt7"],
        // '''Suspended'''
        ["1P 4P 5P", "suspended fourth", "sus4 sus"],
        ["1P 2M 5P", "suspended second", "sus2"],
        ["1P 4P 5P 7m", "suspended fourth seventh", "7sus4 7sus"],
        ["1P 5P 7m 9M 11P", "eleventh", "11"],
        [
          "1P 4P 5P 7m 9m",
          "suspended fourth flat ninth",
          "b9sus phryg 7b9sus 7b9sus4"
        ],
        // ==Other==
        ["1P 5P", "fifth", "5"],
        ["1P 3M 5A", "augmented", "aug + +5 ^#5"],
        ["1P 3m 5A", "minor augmented", "m#5 -#5 m+"],
        ["1P 3M 5A 7M", "augmented seventh", "maj7#5 maj7+5 +maj7 ^7#5"],
        [
          "1P 3M 5P 7M 9M 11A",
          "major sharp eleventh (lydian)",
          "maj9#11 \u03949#11 ^9#11"
        ],
        // ==Legacy==
        ["1P 2M 4P 5P", "", "sus24 sus4add9"],
        ["1P 3M 5A 7M 9M", "", "maj9#5 Maj9#5"],
        ["1P 3M 5A 7m", "", "7#5 +7 7+ 7aug aug7"],
        ["1P 3M 5A 7m 9A", "", "7#5#9 7#9#5 7alt"],
        ["1P 3M 5A 7m 9M", "", "9#5 9+"],
        ["1P 3M 5A 7m 9M 11A", "", "9#5#11"],
        ["1P 3M 5A 7m 9m", "", "7#5b9 7b9#5"],
        ["1P 3M 5A 7m 9m 11A", "", "7#5b9#11"],
        ["1P 3M 5A 9A", "", "+add#9"],
        ["1P 3M 5A 9M", "", "M#5add9 +add9"],
        ["1P 3M 5P 6M 11A", "", "M6#11 M6b5 6#11 6b5"],
        ["1P 3M 5P 6M 7M 9M", "", "M7add13"],
        ["1P 3M 5P 6M 9M 11A", "", "69#11"],
        ["1P 3m 5P 6M 9M", "", "m69 -69"],
        ["1P 3M 5P 6m 7m", "", "7b6"],
        ["1P 3M 5P 7M 9A 11A", "", "maj7#9#11"],
        ["1P 3M 5P 7M 9M 11A 13M", "", "M13#11 maj13#11 M13+4 M13#4"],
        ["1P 3M 5P 7M 9m", "", "M7b9"],
        ["1P 3M 5P 7m 11A 13m", "", "7#11b13 7b5b13"],
        ["1P 3M 5P 7m 13M", "", "7add6 67 7add13"],
        ["1P 3M 5P 7m 9A 11A", "", "7#9#11 7b5#9 7#9b5"],
        ["1P 3M 5P 7m 9A 11A 13M", "", "13#9#11"],
        ["1P 3M 5P 7m 9A 11A 13m", "", "7#9#11b13"],
        ["1P 3M 5P 7m 9A 13M", "", "13#9"],
        ["1P 3M 5P 7m 9A 13m", "", "7#9b13"],
        ["1P 3M 5P 7m 9M 11A", "", "9#11 9+4 9#4"],
        ["1P 3M 5P 7m 9M 11A 13M", "", "13#11 13+4 13#4"],
        ["1P 3M 5P 7m 9M 11A 13m", "", "9#11b13 9b5b13"],
        ["1P 3M 5P 7m 9m 11A", "", "7b9#11 7b5b9 7b9b5"],
        ["1P 3M 5P 7m 9m 11A 13M", "", "13b9#11"],
        ["1P 3M 5P 7m 9m 11A 13m", "", "7b9b13#11 7b9#11b13 7b5b9b13"],
        ["1P 3M 5P 7m 9m 13M", "", "13b9"],
        ["1P 3M 5P 7m 9m 13m", "", "7b9b13"],
        ["1P 3M 5P 7m 9m 9A", "", "7b9#9"],
        ["1P 3M 5P 9M", "", "Madd9 2 add9 add2"],
        ["1P 3M 5P 9m", "", "Maddb9"],
        ["1P 3M 5d", "", "Mb5"],
        ["1P 3M 5d 6M 7m 9M", "", "13b5"],
        ["1P 3M 5d 7M", "", "M7b5"],
        ["1P 3M 5d 7M 9M", "", "M9b5"],
        ["1P 3M 5d 7m", "", "7b5"],
        ["1P 3M 5d 7m 9M", "", "9b5"],
        ["1P 3M 7m", "", "7no5"],
        ["1P 3M 7m 13m", "", "7b13"],
        ["1P 3M 7m 9M", "", "9no5"],
        ["1P 3M 7m 9M 13M", "", "13no5"],
        ["1P 3M 7m 9M 13m", "", "9b13"],
        ["1P 3m 4P 5P", "", "madd4"],
        ["1P 3m 5P 6m 7M", "", "mMaj7b6"],
        ["1P 3m 5P 6m 7M 9M", "", "mMaj9b6"],
        ["1P 3m 5P 7m 11P", "", "m7add11 m7add4"],
        ["1P 3m 5P 9M", "", "madd9"],
        ["1P 3m 5d 6M 7M", "", "o7M7"],
        ["1P 3m 5d 7M", "", "oM7"],
        ["1P 3m 6m 7M", "", "mb6M7"],
        ["1P 3m 6m 7m", "", "m7#5"],
        ["1P 3m 6m 7m 9M", "", "m9#5"],
        ["1P 3m 5A 7m 9M 11P", "", "m11A"],
        ["1P 3m 6m 9m", "", "mb6b9"],
        ["1P 2M 3m 5d 7m", "", "m9b5"],
        ["1P 4P 5A 7M", "", "M7#5sus4"],
        ["1P 4P 5A 7M 9M", "", "M9#5sus4"],
        ["1P 4P 5A 7m", "", "7#5sus4"],
        ["1P 4P 5P 7M", "", "M7sus4"],
        ["1P 4P 5P 7M 9M", "", "M9sus4"],
        ["1P 4P 5P 7m 9M", "", "9sus4 9sus"],
        ["1P 4P 5P 7m 9M 13M", "", "13sus4 13sus"],
        ["1P 4P 5P 7m 9m 13m", "", "7sus4b9b13 7b9b13sus4"],
        ["1P 4P 7m 10m", "", "4 quartal"],
        ["1P 5P 7m 9m 11P", "", "11b9"]
      ];
      var data_default = CHORDS;
      var NoChordType = {
        ...import_pcset.EmptyPcset,
        name: "",
        quality: "Unknown",
        intervals: [],
        aliases: []
      };
      var dictionary = [];
      var index = {};
      function get(type) {
        return index[type] || NoChordType;
      }
      var chordType = get;
      function names() {
        return dictionary.map((chord) => chord.name).filter((x2) => x2);
      }
      function symbols() {
        return dictionary.map((chord) => chord.aliases[0]).filter((x2) => x2);
      }
      function keys() {
        return Object.keys(index);
      }
      function all() {
        return dictionary.slice();
      }
      var entries = all;
      function removeAll() {
        dictionary = [];
        index = {};
      }
      function add2(intervals, aliases, fullName) {
        const quality = getQuality(intervals);
        const chord = {
          ...(0, import_pcset.get)(intervals),
          name: fullName || "",
          quality,
          intervals,
          aliases
        };
        dictionary.push(chord);
        if (chord.name) {
          index[chord.name] = chord;
        }
        index[chord.setNum] = chord;
        index[chord.chroma] = chord;
        chord.aliases.forEach((alias) => addAlias(chord, alias));
      }
      function addAlias(chord, alias) {
        index[alias] = chord;
      }
      function getQuality(intervals) {
        const has = (interval) => intervals.indexOf(interval) !== -1;
        return has("5A") ? "Augmented" : has("3M") ? "Major" : has("5d") ? "Diminished" : has("3m") ? "Minor" : "Unknown";
      }
      data_default.forEach(
        ([ivls, fullName, names2]) => add2(ivls.split(" "), names2.split(" "), fullName)
      );
      dictionary.sort((a2, b2) => a2.setNum - b2.setNum);
      var chord_type_default = {
        names,
        symbols,
        get,
        all,
        add: add2,
        removeAll,
        keys,
        // deprecated
        entries,
        chordType
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/scale/dist/index.js
  var require_dist42 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/scale/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all2) => {
        for (var name in all2)
          __defProp2(target, name, { get: all2[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var index_exports = {};
      __export2(index_exports, {
        default: () => index_default,
        degrees: () => degrees,
        detect: () => detect2,
        extended: () => extended,
        get: () => get,
        modeNames: () => modeNames,
        names: () => names,
        rangeOf: () => rangeOf,
        reduced: () => reduced,
        scale: () => scale,
        scaleChords: () => scaleChords,
        scaleNotes: () => scaleNotes,
        steps: () => steps,
        tokenize: () => tokenize
      });
      module.exports = __toCommonJS(index_exports);
      var import_chord_type = require_dist41();
      var import_collection = require_dist8();
      var import_note = require_dist25();
      var import_pcset = require_dist11();
      var import_pitch_distance = require_dist5();
      var import_pitch_note = require_dist4();
      var import_scale_type = require_dist20();
      var NoScale = {
        empty: true,
        name: "",
        type: "",
        tonic: null,
        setNum: NaN,
        chroma: "",
        normalized: "",
        aliases: [],
        notes: [],
        intervals: []
      };
      function tokenize(name) {
        if (typeof name !== "string") {
          return ["", ""];
        }
        const i = name.indexOf(" ");
        const tonic = (0, import_pitch_note.note)(name.substring(0, i));
        if (tonic.empty) {
          const n2 = (0, import_pitch_note.note)(name);
          return n2.empty ? ["", name.toLowerCase()] : [n2.name, ""];
        }
        const type = name.substring(tonic.name.length + 1).toLowerCase();
        return [tonic.name, type.length ? type : ""];
      }
      var names = import_scale_type.names;
      function get(src) {
        const tokens = Array.isArray(src) ? src : tokenize(src);
        const tonic = (0, import_pitch_note.note)(tokens[0]).name;
        const st4 = (0, import_scale_type.get)(tokens[1]);
        if (st4.empty) {
          return NoScale;
        }
        const type = st4.name;
        const notes = tonic ? st4.intervals.map((i) => (0, import_pitch_distance.transpose)(tonic, i)) : [];
        const name = tonic ? tonic + " " + type : type;
        return { ...st4, name, type, tonic, notes };
      }
      var scale = get;
      function detect2(notes, options = {}) {
        const notesChroma = (0, import_pcset.chroma)(notes);
        const tonic = (0, import_pitch_note.note)(options.tonic ?? notes[0] ?? "");
        const tonicChroma = tonic.chroma;
        if (tonicChroma === void 0) {
          return [];
        }
        const pitchClasses = notesChroma.split("");
        pitchClasses[tonicChroma] = "1";
        const scaleChroma = (0, import_collection.rotate)(tonicChroma, pitchClasses).join("");
        const match = (0, import_scale_type.all)().find((scaleType) => scaleType.chroma === scaleChroma);
        const results = [];
        if (match) {
          results.push(tonic.name + " " + match.name);
        }
        if (options.match === "exact") {
          return results;
        }
        extended(scaleChroma).forEach((scaleName) => {
          results.push(tonic.name + " " + scaleName);
        });
        return results;
      }
      function scaleChords(name) {
        const s2 = get(name);
        const inScale = (0, import_pcset.isSubsetOf)(s2.chroma);
        return (0, import_chord_type.all)().filter((chord) => inScale(chord.chroma)).map((chord) => chord.aliases[0]);
      }
      function extended(name) {
        const chroma2 = (0, import_pcset.isChroma)(name) ? name : get(name).chroma;
        const isSuperset = (0, import_pcset.isSupersetOf)(chroma2);
        return (0, import_scale_type.all)().filter((scale2) => isSuperset(scale2.chroma)).map((scale2) => scale2.name);
      }
      function reduced(name) {
        const isSubset = (0, import_pcset.isSubsetOf)(get(name).chroma);
        return (0, import_scale_type.all)().filter((scale2) => isSubset(scale2.chroma)).map((scale2) => scale2.name);
      }
      function scaleNotes(notes) {
        const pcset = notes.map((n2) => (0, import_pitch_note.note)(n2).pc).filter((x2) => x2);
        const tonic = pcset[0];
        const scale2 = (0, import_note.sortedUniqNames)(pcset);
        return (0, import_collection.rotate)(scale2.indexOf(tonic), scale2);
      }
      function modeNames(name) {
        const s2 = get(name);
        if (s2.empty) {
          return [];
        }
        const tonics = s2.tonic ? s2.notes : s2.intervals;
        return (0, import_pcset.modes)(s2.chroma).map((chroma2, i) => {
          const modeName = get(chroma2).name;
          return modeName ? [tonics[i], modeName] : ["", ""];
        }).filter((x2) => x2[0]);
      }
      function getNoteNameOf(scale2) {
        const names2 = Array.isArray(scale2) ? scaleNotes(scale2) : get(scale2).notes;
        const chromas = names2.map((name) => (0, import_pitch_note.note)(name).chroma);
        return (noteOrMidi) => {
          const currNote = typeof noteOrMidi === "number" ? (0, import_pitch_note.note)((0, import_note.fromMidi)(noteOrMidi)) : (0, import_pitch_note.note)(noteOrMidi);
          const height = currNote.height;
          if (height === void 0) return void 0;
          const chroma2 = height % 12;
          const position = chromas.indexOf(chroma2);
          if (position === -1) return void 0;
          return (0, import_note.enharmonic)(currNote.name, names2[position]);
        };
      }
      function rangeOf(scale2) {
        const getName = getNoteNameOf(scale2);
        return (fromNote, toNote) => {
          const from = (0, import_pitch_note.note)(fromNote).height;
          const to3 = (0, import_pitch_note.note)(toNote).height;
          if (from === void 0 || to3 === void 0) return [];
          return (0, import_collection.range)(from, to3).map(getName).filter((x2) => x2);
        };
      }
      function degrees(scaleName) {
        const { intervals, tonic } = get(scaleName);
        const transpose2 = (0, import_pitch_distance.tonicIntervalsTransposer)(intervals, tonic);
        return (degree) => degree ? transpose2(degree > 0 ? degree - 1 : degree) : "";
      }
      function steps(scaleName) {
        const { intervals, tonic } = get(scaleName);
        return (0, import_pitch_distance.tonicIntervalsTransposer)(intervals, tonic);
      }
      var index_default = {
        degrees,
        detect: detect2,
        extended,
        get,
        modeNames,
        names,
        rangeOf,
        reduced,
        scaleChords,
        scaleNotes,
        steps,
        tokenize,
        // deprecated
        scale
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/time-signature/dist/index.js
  var require_dist43 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/time-signature/dist/index.js"(exports, module) {
      "use strict";
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var time_signature_exports = {};
      __export2(time_signature_exports, {
        default: () => time_signature_default,
        get: () => get,
        names: () => names,
        parse: () => parse2
      });
      module.exports = __toCommonJS(time_signature_exports);
      var NONE = {
        empty: true,
        name: "",
        upper: void 0,
        lower: void 0,
        type: void 0,
        additive: []
      };
      var NAMES = ["4/4", "3/4", "2/4", "2/2", "12/8", "9/8", "6/8", "3/8"];
      function names() {
        return NAMES.slice();
      }
      var REGEX = /^(\d*\d(?:\+\d)*)\/(\d+)$/;
      var CACHE = /* @__PURE__ */ new Map();
      function get(literal) {
        const stringifiedLiteral = JSON.stringify(literal);
        const cached = CACHE.get(stringifiedLiteral);
        if (cached) {
          return cached;
        }
        const ts2 = build(parse2(literal));
        CACHE.set(stringifiedLiteral, ts2);
        return ts2;
      }
      function parse2(literal) {
        if (typeof literal === "string") {
          const [_5, up22, low] = REGEX.exec(literal) || [];
          return parse2([up22, low]);
        }
        const [up2, down] = literal;
        const denominator = +down;
        if (typeof up2 === "number") {
          return [up2, denominator];
        }
        const list = up2.split("+").map((n2) => +n2);
        return list.length === 1 ? [list[0], denominator] : [list, denominator];
      }
      var time_signature_default = { names, parse: parse2, get };
      var isPowerOfTwo = (x2) => Math.log(x2) / Math.log(2) % 1 === 0;
      function build([up2, down]) {
        const upper = Array.isArray(up2) ? up2.reduce((a2, b2) => a2 + b2, 0) : up2;
        const lower = down;
        if (upper === 0 || lower === 0) {
          return NONE;
        }
        const name = Array.isArray(up2) ? `${up2.join("+")}/${down}` : `${up2}/${down}`;
        const additive = Array.isArray(up2) ? up2 : [];
        const type = lower === 4 || lower === 2 ? "simple" : lower === 8 && upper % 3 === 0 ? "compound" : isPowerOfTwo(lower) ? "irregular" : "irrational";
        return {
          empty: false,
          name,
          type,
          upper,
          lower,
          additive
        };
      }
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/tonal/dist/index.js
  var require_dist44 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@tonaljs/tonal/dist/index.js"(exports, module) {
      "use strict";
      var __create2 = Object.create;
      var __defProp2 = Object.defineProperty;
      var __getOwnPropDesc2 = Object.getOwnPropertyDescriptor;
      var __getOwnPropNames2 = Object.getOwnPropertyNames;
      var __getProtoOf2 = Object.getPrototypeOf;
      var __hasOwnProp2 = Object.prototype.hasOwnProperty;
      var __export2 = (target, all) => {
        for (var name in all)
          __defProp2(target, name, { get: all[name], enumerable: true });
      };
      var __copyProps2 = (to3, from, except, desc) => {
        if (from && typeof from === "object" || typeof from === "function") {
          for (let key of __getOwnPropNames2(from))
            if (!__hasOwnProp2.call(to3, key) && key !== except)
              __defProp2(to3, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc2(from, key)) || desc.enumerable });
        }
        return to3;
      };
      var __reExport = (target, mod, secondTarget) => (__copyProps2(target, mod, "default"), secondTarget && __copyProps2(secondTarget, mod, "default"));
      var __toESM2 = (mod, isNodeMode, target) => (target = mod != null ? __create2(__getProtoOf2(mod)) : {}, __copyProps2(
        isNodeMode || !mod || !mod.__esModule ? __defProp2(target, "default", { value: mod, enumerable: true }) : target,
        mod
      ));
      var __toCommonJS = (mod) => __copyProps2(__defProp2({}, "__esModule", { value: true }), mod);
      var tonal_tonal_exports = {};
      __export2(tonal_tonal_exports, {
        AbcNotation: () => import_abc_notation.default,
        Array: () => Array2,
        Chord: () => import_chord.default,
        ChordDictionary: () => ChordDictionary,
        ChordType: () => import_chord_type.default,
        Collection: () => import_collection.default,
        Core: () => Core,
        DurationValue: () => import_duration_value.default,
        Interval: () => import_interval.default,
        Key: () => import_key.default,
        Midi: () => import_midi.default,
        Mode: () => import_mode.default,
        Note: () => import_note.default,
        PcSet: () => PcSet,
        Pcset: () => import_pcset.default,
        Progression: () => import_progression.default,
        Range: () => import_range.default,
        RomanNumeral: () => import_roman_numeral.default,
        Scale: () => import_scale.default,
        ScaleDictionary: () => ScaleDictionary,
        ScaleType: () => import_scale_type.default,
        TimeSignature: () => import_time_signature.default,
        Tonal: () => Tonal
      });
      module.exports = __toCommonJS(tonal_tonal_exports);
      var import_abc_notation = __toESM2(require_dist6());
      var Array2 = __toESM2(require_dist7());
      var import_chord = __toESM2(require_dist21());
      var import_chord_type = __toESM2(require_dist19());
      var import_collection = __toESM2(require_dist8());
      var Core = __toESM2(require_dist18());
      var import_duration_value = __toESM2(require_dist22());
      var import_interval = __toESM2(require_dist23());
      var import_key = __toESM2(require_dist29());
      var import_midi = __toESM2(require_dist24());
      var import_mode = __toESM2(require_dist33());
      var import_note = __toESM2(require_dist25());
      var import_pcset = __toESM2(require_dist11());
      var import_progression = __toESM2(require_dist39());
      var import_range = __toESM2(require_dist40());
      var import_roman_numeral = __toESM2(require_dist28());
      var import_scale = __toESM2(require_dist42());
      var import_scale_type = __toESM2(require_dist20());
      var import_time_signature = __toESM2(require_dist43());
      __reExport(tonal_tonal_exports, require_dist18(), module.exports);
      var Tonal = Core;
      var PcSet = import_pcset.default;
      var ChordDictionary = import_chord_type.default;
      var ScaleDictionary = import_scale_type.default;
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/getBestVoicing.js
  var require_getBestVoicing = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/getBestVoicing.js"(exports) {
      "use strict";
      exports.__esModule = true;
      exports.getBestVoicing = void 0;
      function getBestVoicing(voicingOptions) {
        var chord = voicingOptions.chord, range = voicingOptions.range, finder = voicingOptions.finder, picker = voicingOptions.picker, lastVoicing = voicingOptions.lastVoicing;
        var voicings = finder(chord, range);
        if (!voicings.length) {
          return [];
        }
        return picker(voicings, lastVoicing);
      }
      exports.getBestVoicing = getBestVoicing;
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/tokenizeChord.js
  var require_tokenizeChord = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/tokenizeChord.js"(exports) {
      "use strict";
      exports.__esModule = true;
      exports.tokenizeChord = void 0;
      function tokenizeChord(chord) {
        var match = (chord || "").match(/^([A-G][b#]*)([^\/]*)[\/]?([A-G][b#]*)?$/);
        if (!match) {
          return [];
        }
        return match.slice(1);
      }
      exports.tokenizeChord = tokenizeChord;
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/voicingsInRange.js
  var require_voicingsInRange = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/voicingsInRange.js"(exports) {
      "use strict";
      exports.__esModule = true;
      exports.voicingsInRange = void 0;
      var tonal_1 = require_dist44();
      var dictionaryVoicing_1 = require_dictionaryVoicing();
      var tokenizeChord_1 = require_tokenizeChord();
      function voicingsInRange(chord, dictionary, range) {
        if (dictionary === void 0) {
          dictionary = dictionaryVoicing_1.lefthand;
        }
        if (range === void 0) {
          range = ["D3", "A4"];
        }
        var _a2 = (0, tokenizeChord_1.tokenizeChord)(chord), tonic = _a2[0], symbol = _a2[1];
        if (!dictionary[symbol]) {
          return [];
        }
        var voicings = dictionary[symbol].map(function(intervals) {
          return intervals.split(" ");
        });
        var notesInRange = tonal_1.Range.chromatic(range);
        return voicings.reduce(function(voiced, voicing) {
          var relativeIntervals = voicing.map(function(interval) {
            return tonal_1.Interval.substract(interval, voicing[0]);
          });
          var bottomPitchClass = tonal_1.Note.transpose(tonic, voicing[0]);
          var starts = notesInRange.filter(function(note) {
            return tonal_1.Note.chroma(note) === tonal_1.Note.chroma(bottomPitchClass);
          }).filter(function(note) {
            return tonal_1.Note.midi(tonal_1.Note.transpose(note, relativeIntervals[relativeIntervals.length - 1])) <= tonal_1.Note.midi(range[1]);
          }).map(function(note) {
            return tonal_1.Note.enharmonic(note, bottomPitchClass);
          });
          var notes = starts.map(function(start) {
            return relativeIntervals.map(function(interval) {
              return tonal_1.Note.transpose(start, interval);
            });
          });
          return voiced.concat(notes);
        }, []);
      }
      exports.voicingsInRange = voicingsInRange;
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/dictionaryVoicing.js
  var require_dictionaryVoicing = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/dictionaryVoicing.js"(exports) {
      "use strict";
      var __assign = exports && exports.__assign || function() {
        __assign = Object.assign || function(t) {
          for (var s2, i = 1, n2 = arguments.length; i < n2; i++) {
            s2 = arguments[i];
            for (var p2 in s2) if (Object.prototype.hasOwnProperty.call(s2, p2))
              t[p2] = s2[p2];
          }
          return t;
        };
        return __assign.apply(this, arguments);
      };
      var __rest = exports && exports.__rest || function(s2, e) {
        var t = {};
        for (var p2 in s2) if (Object.prototype.hasOwnProperty.call(s2, p2) && e.indexOf(p2) < 0)
          t[p2] = s2[p2];
        if (s2 != null && typeof Object.getOwnPropertySymbols === "function")
          for (var i = 0, p2 = Object.getOwnPropertySymbols(s2); i < p2.length; i++) {
            if (e.indexOf(p2[i]) < 0 && Object.prototype.propertyIsEnumerable.call(s2, p2[i]))
              t[p2[i]] = s2[p2[i]];
          }
        return t;
      };
      exports.__esModule = true;
      exports.dictionaryVoicing = exports.dictionaryVoicingFinder = exports.triads = exports.guidetones = exports.lefthand = void 0;
      var getBestVoicing_1 = require_getBestVoicing();
      var voicingsInRange_1 = require_voicingsInRange();
      exports.lefthand = {
        m7: ["3m 5P 7m 9M", "7m 9M 10m 12P"],
        "7": ["3M 6M 7m 9M", "7m 9M 10M 13M"],
        "^7": ["3M 5P 7M 9M", "7M 9M 10M 12P"],
        "69": ["3M 5P 6A 9M"],
        m7b5: ["3m 5d 7m 8P", "7m 8P 10m 12d"],
        "7b9": ["3M 6m 7m 9m", "7m 9m 10M 13m"],
        "7b13": ["3M 6m 7m 9m", "7m 9m 10M 13m"],
        o7: ["1P 3m 5d 6M", "5d 6M 8P 10m"],
        "7#11": ["7m 9M 11A 13A"],
        "7#9": ["3M 7m 9A"],
        mM7: ["3m 5P 7M 9M", "7M 9M 10m 12P"],
        m6: ["3m 5P 6M 9M", "6M 9M 10m 12P"]
      };
      exports.guidetones = {
        m7: ["3m 7m", "7m 10m"],
        m9: ["3m 7m", "7m 10m"],
        "7": ["3M 7m", "7m 10M"],
        "^7": ["3M 7M", "7M 10M"],
        "^9": ["3M 7M", "7M 10M"],
        "69": ["3M 6M"],
        "6": ["3M 6M", "6M 10M"],
        m7b5: ["3m 7m", "7m 10m"],
        "7b9": ["3M 7m", "7m 10M"],
        "7b13": ["3M 7m", "7m 10M"],
        o7: ["3m 6M", "6M 10m"],
        "7#11": ["3M 7m", "7m 10M"],
        "7#9": ["3M 7m", "7m 10M"],
        mM7: ["3m 7M", "7M 10m"],
        m6: ["3m 6M", "6M 10m"]
      };
      exports.triads = {
        M: ["1P 3M 5P", "3M 5P 8P", "5P 8P 10M"],
        m: ["1P 3m 5P", "3m 5P 8P", "5P 8P 10m"],
        o: ["1P 3m 5d", "3m 5d 8P", "5d 8P 10m"],
        aug: ["1P 3m 5A", "3m 5A 8P", "5A 8P 10m"]
      };
      var dictionaryVoicingFinder = function(dictionary) {
        return function(chordSymbol, range) {
          return (0, voicingsInRange_1.voicingsInRange)(chordSymbol, dictionary, range);
        };
      };
      exports.dictionaryVoicingFinder = dictionaryVoicingFinder;
      var dictionaryVoicing = function(props) {
        var dictionary = props.dictionary, range = props.range, rest = __rest(props, ["dictionary", "range"]);
        return (0, getBestVoicing_1.getBestVoicing)(__assign(__assign({}, rest), { range, finder: (0, exports.dictionaryVoicingFinder)(dictionary) }));
      };
      exports.dictionaryVoicing = dictionaryVoicing;
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/minTopNoteDiff.js
  var require_minTopNoteDiff = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/minTopNoteDiff.js"(exports) {
      "use strict";
      exports.__esModule = true;
      exports.minTopNoteDiff = void 0;
      var tonal_1 = require_dist44();
      function minTopNoteDiff(voicings, lastVoicing) {
        if (!lastVoicing) {
          return voicings[0];
        }
        var diff = function(voicing) {
          return Math.abs(tonal_1.Note.midi(lastVoicing[lastVoicing.length - 1]) - tonal_1.Note.midi(voicing[voicing.length - 1]));
        };
        return voicings.reduce(function(best, current) {
          return diff(current) < diff(best) ? current : best;
        }, voicings[0]);
      }
      exports.minTopNoteDiff = minTopNoteDiff;
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/index.js
  var require_dist45 = __commonJS({
    "../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/chord-voicings/dist/index.js"(exports) {
      "use strict";
      exports.__esModule = true;
      var dictionaryVoicing_1 = require_dictionaryVoicing();
      var minTopNoteDiff_1 = require_minTopNoteDiff();
      var getBestVoicing_1 = require_getBestVoicing();
      var tokenizeChord_1 = require_tokenizeChord();
      exports["default"] = {
        tokenizeChord: tokenizeChord_1.tokenizeChord,
        getBestVoicing: getBestVoicing_1.getBestVoicing,
        dictionaryVoicing: dictionaryVoicing_1.dictionaryVoicing,
        dictionaryVoicingFinder: dictionaryVoicing_1.dictionaryVoicingFinder,
        lefthand: dictionaryVoicing_1.lefthand,
        guidetones: dictionaryVoicing_1.guidetones,
        triads: dictionaryVoicing_1.triads,
        minTopNoteDiff: minTopNoteDiff_1.minTopNoteDiff
      };
    }
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/core/dist/index.mjs
  var dist_exports = {};
  __export(dist_exports, {
    ClockCollator: () => _n,
    Cyclist: () => hf,
    FXr: () => uf,
    FXrel: () => cf,
    FXrelease: () => of,
    Fraction: () => m,
    Hap: () => S2,
    Pattern: () => f2,
    State: () => ut2,
    TimeSpan: () => B2,
    __chooseWith: () => Me2,
    _brandBy: () => Oe2,
    _fitslice: () => Fn,
    _irand: () => ze2,
    _keyDown: () => je2,
    _match: () => In,
    _mod: () => bt2,
    _morph: () => de2,
    _polymeterListSteps: () => Hn,
    _retime: () => Yt2,
    _slices: () => Zt2,
    accelerate: () => Ys,
    activeLabel: () => va,
    ad: () => Bp,
    add: () => $h,
    adsr: () => xp,
    almostAlways: () => Jw,
    almostNever: () => jw,
    always: () => Nw,
    amp: () => sr,
    analyze: () => gc,
    anchor: () => Ua,
    and: () => nd,
    apply: () => Pd,
    applyN: () => Wn,
    ar: () => zp,
    arp: () => wh,
    arpWith: () => yh,
    arrange: () => kh,
    as: () => Kp,
    asym: () => py,
    att: () => or,
    attack: () => rr,
    averageArray: () => nn,
    backgroundImage: () => Hw,
    band: () => Ih,
    bandf: () => Cc,
    bandq: () => Oc,
    bank: () => yc,
    base64ToUnicode: () => gn,
    bbexpr: () => ti2,
    bbst: () => ni2,
    beat: () => oy,
    begin: () => Mc,
    berlin: () => qw,
    bgain: () => ja,
    binary: () => iw,
    binaryL: () => uw,
    binaryN: () => Jf,
    binaryNL: () => $f,
    bind: () => xh,
    binshift: () => Zl,
    bite: () => Ld,
    bjork: () => _y,
    bjorklund: () => ge2,
    blshift: () => Dh,
    bmod: () => sf,
    bor: () => Vh,
    bp: () => Bc,
    bpa: () => ji2,
    bpattack: () => Ei2,
    bpd: () => Wi2,
    bpdc: () => yu,
    bpdecay: () => Ri2,
    bpdepth: () => fu,
    bpdepthfreq: () => du,
    bpdepthfrequency: () => hu,
    bpe: () => Bi2,
    bpenv: () => xi2,
    bpf: () => xc,
    bpq: () => zc,
    bpr: () => Zi2,
    bprate: () => lu,
    bprelease: () => Yi2,
    bps: () => Gi2,
    bpshape: () => mu,
    bpskew: () => wu,
    bpsustain: () => Di2,
    bpsync: () => pu,
    brak: () => Ud,
    brand: () => mw,
    brandBy: () => dw,
    brshift: () => Gh,
    bus: () => Pa,
    busgain: () => Ea,
    bxor: () => Hh,
    bypass: () => Tm,
    byteBeatExpression: () => Zc,
    byteBeatStartTime: () => ei2,
    calculateSteps: () => dh,
    cat: () => mt2,
    ccn: () => $p,
    ccv: () => Np,
    ceil: () => id,
    ch: () => ri2,
    channel: () => gi2,
    channels: () => si2,
    chebyshev: () => dy,
    choose: () => Rf,
    chooseCycles: () => Wf,
    chooseIn: () => ww,
    chooseInWith: () => Pe2,
    chooseOut: () => gw,
    chooseWith: () => It2,
    chop: () => Xm,
    chord: () => Da,
    chorus: () => wc,
    chunk: () => mm,
    chunkBack: () => gm,
    chunkBackInto: () => Am,
    chunkInto: () => qm,
    chunkback: () => bm,
    chunkbackinto: () => Sm,
    chunkinto: () => km,
    clamp: () => an,
    cleanupUi: () => Dw,
    clip: () => pp,
    coarse: () => Rc,
    code2hash: () => ph,
    color: () => Ap,
    colour: () => Tp,
    comb: () => Xl,
    compose: () => oh,
    compress: () => dd,
    compressSpan: () => md,
    compressor: () => bl,
    compressorAttack: () => kl,
    compressorKnee: () => _l,
    compressorRatio: () => vl,
    compressorRelease: () => ql,
    compressspan: () => yd,
    constant: () => ch,
    contract: () => Kn,
    control: () => Jp,
    controls: () => gy,
    cosine: () => Qy,
    cosine2: () => Uy,
    cpm: () => Ed,
    cps: () => lp,
    createClock: () => ff,
    createParam: () => Nt2,
    createParams: () => Cp,
    crush: () => Lc,
    ctf: () => vi2,
    ctlNum: () => Lp,
    ctranspose: () => Aa,
    cubic: () => ay,
    curry: () => w2,
    curve: () => yp,
    cut: () => bi2,
    cutoff: () => _i2,
    cycleToSeconds: () => Kt2,
    cyclesPer: () => Ww,
    dec: () => vc,
    decay: () => _c,
    degrade: () => Tw,
    degradeBy: () => Aw,
    degradeByWith: () => Sw,
    degree: () => qa,
    delay: () => Ru,
    delayfb: () => Fu,
    delayfeedback: () => Wu,
    delayspeed: () => Vu,
    delaysync: () => Qu,
    delayt: () => Du,
    delaytime: () => Hu,
    deltaSlide: () => wp,
    det: () => Ku,
    detune: () => Xu,
    dfb: () => Iu,
    dict: () => Qa,
    dictionary: () => Ga,
    diode: () => ly,
    dist: () => yl,
    distort: () => ml,
    distorttype: () => gl,
    distortvol: () => wl,
    div: () => Rh,
    djf: () => Lu,
    drawLine: () => Cn,
    drive: () => Qc,
    drop: () => Qn,
    dry: () => ta,
    ds: () => Op,
    dt: () => Gu,
    duck: () => Uc,
    duckattack: () => Yc,
    duckdepth: () => Xc,
    duckonset: () => Kc,
    dur: () => dp,
    duration: () => hp,
    early: () => jd,
    echo: () => im,
    echoWith: () => sm,
    echowith: () => rm,
    eish: () => Ty,
    end: () => Pc,
    enhance: () => Ul,
    env: () => nf,
    eq: () => Yh,
    eqt: () => Zh,
    errorLogger: () => zt2,
    euclid: () => by,
    euclidLegato: () => qy,
    euclidLegatoRot: () => Sy,
    euclidRot: () => ky,
    euclidish: () => Ay,
    euclidrot: () => vy,
    evalScope: () => xn,
    evaluate: () => On,
    every: () => Md,
    expand: () => Xn,
    expression: () => Ol,
    extend: () => Un,
    fadeInTime: () => sa,
    fadeOutTime: () => na,
    fadeTime: () => ea,
    fanchor: () => eu,
    fast: () => qd,
    fastChunk: () => vm,
    fastGap: () => wd,
    fastcat: () => N2,
    fastchunk: () => _m,
    fastgap: () => gd,
    fft: () => bc,
    filter: () => zm,
    filterWhen: () => Mm,
    firstOf: () => zd,
    fit: () => ey,
    flatten: () => G,
    floor: () => cd,
    fm: () => Sr,
    fm1: () => Ar,
    fm2: () => Tr,
    fm3: () => Cr,
    fm4: () => xr,
    fm5: () => Br,
    fm6: () => Or,
    fm7: () => zr,
    fm8: () => Mr,
    fmatt: () => Kr,
    fmatt1: () => Yr,
    fmatt2: () => Zr,
    fmatt3: () => to,
    fmatt4: () => eo,
    fmatt5: () => no,
    fmatt6: () => so,
    fmatt7: () => ro,
    fmatt8: () => oo,
    fmattack: () => Fr,
    fmattack1: () => Ir,
    fmattack2: () => Vr,
    fmattack3: () => Hr,
    fmattack4: () => Dr,
    fmattack5: () => Gr,
    fmattack6: () => Qr,
    fmattack7: () => Ur,
    fmattack8: () => Xr,
    fmdec: () => Ao,
    fmdec1: () => To,
    fmdec2: () => Co,
    fmdec3: () => xo,
    fmdec4: () => Bo,
    fmdec5: () => Oo,
    fmdec6: () => zo,
    fmdec7: () => Mo,
    fmdec8: () => Po,
    fmdecay: () => yo,
    fmdecay1: () => wo,
    fmdecay2: () => go,
    fmdecay3: () => bo,
    fmdecay4: () => _o,
    fmdecay5: () => vo,
    fmdecay6: () => ko,
    fmdecay7: () => qo,
    fmdecay8: () => So,
    fmenv: () => Pr,
    fmenv1: () => Er,
    fmenv2: () => jr,
    fmenv3: () => Jr,
    fmenv4: () => $r,
    fmenv5: () => Nr,
    fmenv6: () => Lr,
    fmenv7: () => Rr,
    fmenv8: () => Wr,
    fmh: () => cr,
    fmh1: () => ir,
    fmh2: () => ur,
    fmh3: () => ar,
    fmh4: () => lr,
    fmh5: () => pr,
    fmh6: () => fr,
    fmh7: () => hr,
    fmh8: () => dr,
    fmi: () => mr,
    fmi1: () => yr,
    fmi2: () => wr,
    fmi3: () => gr,
    fmi4: () => br,
    fmi5: () => _r,
    fmi6: () => vr,
    fmi7: () => kr,
    fmi8: () => qr,
    fmrel: () => ic,
    fmrel1: () => uc,
    fmrel2: () => ac,
    fmrel3: () => lc,
    fmrel4: () => pc,
    fmrel5: () => fc,
    fmrel6: () => hc,
    fmrel7: () => dc,
    fmrel8: () => mc,
    fmrelease: () => Yo,
    fmrelease1: () => Zo,
    fmrelease2: () => tc,
    fmrelease3: () => ec,
    fmrelease4: () => nc,
    fmrelease5: () => sc,
    fmrelease6: () => rc,
    fmrelease7: () => oc,
    fmrelease8: () => cc,
    fmsus: () => Io,
    fmsus1: () => Vo,
    fmsus2: () => Ho,
    fmsus3: () => Do,
    fmsus4: () => Go,
    fmsus5: () => Qo,
    fmsus6: () => Uo,
    fmsus7: () => Xo,
    fmsus8: () => Ko,
    fmsustain: () => Eo,
    fmsustain1: () => jo,
    fmsustain2: () => Jo,
    fmsustain3: () => $o,
    fmsustain4: () => No,
    fmsustain5: () => Lo,
    fmsustain6: () => Ro,
    fmsustain7: () => Wo,
    fmsustain8: () => Fo,
    fmwave: () => co,
    fmwave1: () => io,
    fmwave2: () => uo,
    fmwave3: () => ao,
    fmwave4: () => lo,
    fmwave5: () => po,
    fmwave6: () => fo,
    fmwave7: () => ho,
    fmwave8: () => mo,
    focus: () => bd,
    focusSpan: () => _d,
    focusspan: () => vd,
    fold: () => fy,
    fractionalArgs: () => ih,
    frameRate: () => np,
    frames: () => sp,
    freeze: () => Vl,
    freq: () => ra,
    freqToMidi: () => Ze2,
    fromBipolar: () => ad,
    fshift: () => Ml,
    fshiftnote: () => Pl,
    fshiftphase: () => El,
    ftype: () => tu,
    func: () => rd,
    fxr: () => af,
    gain: () => er,
    gap: () => pt2,
    gat: () => wa,
    gate: () => ya,
    getAccidentalsOffset: () => Ye2,
    getControlName: () => yt2,
    getCps: () => Fy,
    getCurrentKeyboardState: () => qn,
    getEventOffsetMs: () => th,
    getFreq: () => tn,
    getFrequency: () => rh,
    getIsStarted: () => Hy,
    getPattern: () => Iy,
    getPerformanceTimeSeconds: () => hh,
    getPlayableNoteValue: () => sh,
    getRandsAtTime: () => K2,
    getSoundIndex: () => nh,
    getTime: () => Wy,
    getTrigger: () => Sf,
    getTriggerFunc: () => Vy,
    grow: () => jm,
    gt: () => Uh,
    gte: () => Kh,
    hard: () => uy,
    harmonic: () => Ta,
    hash2code: () => fh,
    hbrick: () => tp,
    hcutoff: () => Mu,
    hold: () => Tc,
    hours: () => rp,
    hp: () => Eu,
    hpa: () => Pi2,
    hpattack: () => Mi2,
    hpd: () => Li2,
    hpdc: () => Su,
    hpdecay: () => Ni2,
    hpdepth: () => _u,
    hpdepthfreq: () => ku,
    hpdepthfrequency: () => vu,
    hpe: () => Ci2,
    hpenv: () => Ti2,
    hpf: () => Pu,
    hpq: () => Ju,
    hpr: () => Ki2,
    hprate: () => gu,
    hprelease: () => Xi2,
    hps: () => Hi2,
    hpshape: () => qu,
    hpskew: () => Au,
    hpsustain: () => Vi2,
    hpsync: () => bu,
    hresonance: () => ju,
    hsl: () => Om,
    hsla: () => Bm,
    hurry: () => Ad,
    id: () => ot2,
    imag: () => Ql,
    inhabit: () => Jy,
    inhabitmod: () => Ny,
    innerBind: () => Bh,
    inside: () => xd,
    inv: () => Dd,
    invert: () => Hd,
    ir: () => cl,
    irand: () => yw,
    irbegin: () => al,
    iresponse: () => il,
    irspeed: () => ul,
    isControlName: () => is,
    isNote: () => Mt2,
    isNoteWithOctave: () => Yf,
    isPattern: () => pe2,
    isaw: () => Rt2,
    isaw2: () => Ae2,
    iter: () => pm,
    iterBack: () => fm,
    iterback: () => hm,
    itri: () => Zy,
    itri2: () => tw,
    jux: () => nm,
    juxBy: () => tm,
    juxby: () => em,
    kcutoff: () => $l,
    keep: () => jh,
    keepif: () => Jh,
    keyAlias: () => kn,
    keyDown: () => Rw,
    krush: () => Jl,
    label: () => ka,
    lastOf: () => Od,
    late: () => Ln,
    lbrick: () => ep,
    legato: () => fp,
    leslie: () => ga,
    lfo: () => ef,
    linger: () => Rd,
    listRange: () => _t2,
    lock: () => Uu,
    logKey: () => oe2,
    logger: () => E2,
    loop: () => Ec,
    loopAt: () => Zm,
    loopAtCps: () => ny,
    loopBegin: () => jc,
    loopEnd: () => $c,
    loopat: () => ty,
    loopatcps: () => sy,
    loopb: () => Jc,
    loope: () => Nc,
    lp: () => qi2,
    lpa: () => zi2,
    lpattack: () => Oi2,
    lpd: () => $i2,
    lpdc: () => uu,
    lpdecay: () => Ji2,
    lpdepth: () => ru,
    lpdepthfreq: () => cu,
    lpdepthfrequency: () => ou,
    lpe: () => Ai2,
    lpenv: () => Si2,
    lpf: () => ki2,
    lpq: () => Nu,
    lpr: () => Ui2,
    lprate: () => nu,
    lprelease: () => Qi2,
    lps: () => Ii2,
    lpshape: () => iu,
    lpskew: () => au,
    lpsustain: () => Fi2,
    lpsync: () => su,
    lrate: () => ba,
    lsize: () => _a,
    lt: () => Qh,
    lte: () => Xh,
    mapArgs: () => ie2,
    mask: () => Sh,
    midi2note: () => eh,
    midiToFreq: () => it2,
    midibend: () => Dp,
    midichan: () => Mp,
    midicmd: () => jp,
    midimap: () => Pp,
    midiport: () => Ep,
    miditouch: () => Gp,
    minutes: () => op,
    mod: () => Wh,
    mode: () => Ya,
    morph: () => cy,
    mouseX: () => ow,
    mouseY: () => sw,
    mousex: () => rw,
    mousey: () => nw,
    mtranspose: () => Sa,
    mul: () => Lh,
    n: () => Xs,
    nanFallback: () => sn,
    ne: () => td,
    net: () => ed,
    never: () => $w,
    noise: () => Bu,
    note: () => Ks,
    noteToMidi: () => gt2,
    nothing: () => R,
    nrpnn: () => Rp,
    nrpv: () => Wp,
    nudge: () => Ba,
    numeralArgs: () => L2,
    objectMap: () => bn,
    oct: () => za,
    octave: () => Oa,
    octaveR: () => xa,
    octaves: () => Ka,
    octer: () => Nl,
    octersub: () => Ll,
    octersubsub: () => Rl,
    off: () => Qd,
    offset: () => Xa,
    often: () => Pw,
    or: () => sd,
    orbit: () => Ma,
    oschost: () => Up,
    oscport: () => Xp,
    outerBind: () => Oh,
    outside: () => Bd,
    overgain: () => Ja,
    overshape: () => $a,
    pace: () => Vn,
    pairs: () => un,
    palindrome: () => Zd,
    pan: () => Na,
    panchor: () => ma,
    panorient: () => Fa,
    panspan: () => La,
    pansplay: () => Ra,
    panwidth: () => Wa,
    parray: () => me2,
    parseFractional: () => cn,
    parseNumeral: () => ce2,
    partials: () => my,
    patt: () => ca,
    pattack: () => oa,
    pcurve: () => da,
    pdec: () => ua,
    pdecay: () => ia,
    penv: () => ha,
    per: () => Df,
    perCycle: () => Fw,
    perlin: () => kw,
    perx: () => Iw,
    ph: () => ai2,
    phasdp: () => wi2,
    phaser: () => li2,
    phasercenter: () => hi2,
    phaserdepth: () => mi2,
    phaserrate: () => ui2,
    phasersweep: () => pi2,
    phases: () => yy,
    phc: () => di2,
    phd: () => yi2,
    phs: () => fi2,
    pick: () => yf,
    pickF: () => xy,
    pickOut: () => Oy,
    pickReset: () => Ey,
    pickRestart: () => My,
    pickSqueeze: () => $y,
    pickmod: () => gf,
    pickmodF: () => By,
    pickmodOut: () => zy,
    pickmodReset: () => jy,
    pickmodRestart: () => Py,
    pickmodSqueeze: () => Ly,
    pipe: () => on,
    pitchJump: () => gp,
    pitchJumpTime: () => bp,
    ply: () => kd,
    plyForEach: () => lm,
    plyWith: () => am,
    pm: () => _h,
    polyBind: () => Ph,
    polyTouch: () => Qp,
    polymeter: () => $t2,
    polyrhythm: () => gh,
    postgain: () => nr,
    pow: () => Fh,
    pr: () => bh,
    prel: () => fa,
    prelease: () => pa,
    press: () => Yd,
    pressBy: () => Kd,
    progNum: () => Fp,
    psus: () => la,
    psustain: () => aa,
    pure: () => C2,
    pw: () => oi2,
    pwrate: () => ci2,
    pwsweep: () => ii2,
    rand: () => W2,
    rand2: () => hw,
    randL: () => aw,
    randcat: () => bw,
    randrun: () => Nf,
    range: () => ld,
    range2: () => fd,
    rangex: () => pd,
    rarely: () => Ew,
    ratio: () => hd,
    rdim: () => sl,
    real: () => Gl,
    ref: () => ry,
    register: () => l,
    registerControl: () => c2,
    registerMultiControl: () => V2,
    reify: () => d,
    rel: () => Ac,
    release: () => Sc,
    removeUndefineds: () => lt2,
    repeatCycles: () => dm,
    repl: () => Dy,
    replicate: () => Em,
    reset_state: () => df,
    reset_timelines: () => mf,
    resonance: () => $u,
    rev: () => Rn,
    revv: () => Xd,
    rfade: () => ol,
    rib: () => xm,
    ribbon: () => Cm,
    ring: () => Wl,
    ringdf: () => Il,
    ringf: () => Fl,
    rlp: () => el,
    room: () => Za,
    roomdim: () => nl,
    roomfade: () => rl,
    roomlp: () => tl,
    roomsize: () => ll,
    rotate: () => rn,
    round: () => od,
    rsize: () => hl,
    run: () => jf,
    s: () => us,
    s_add: () => Fm,
    s_alt: () => Nm,
    s_cat: () => $m,
    s_contract: () => Dm,
    s_expand: () => Vm,
    s_extend: () => Hm,
    s_polymeter: () => Lm,
    s_sub: () => Im,
    s_taper: () => Rm,
    s_taperlist: () => Wm,
    s_tour: () => Gm,
    s_zip: () => Qm,
    saw: () => qt2,
    saw2: () => Se2,
    scram: () => Yl,
    scramble: () => pw,
    scrub: () => Yp,
    seconds: () => cp,
    seed: () => fw,
    seg: () => Fd,
    segment: () => Wd,
    semitone: () => Va,
    seq: () => Nn,
    seqPLoop: () => qh,
    sequence: () => Q2,
    sequenceP: () => En,
    set: () => Eh,
    setCpsFunc: () => _f,
    setIsStarted: () => qf,
    setPattern: () => vf,
    setStringParser: () => mh,
    setTime: () => ee2,
    setTriggerFunc: () => kf,
    shape: () => dl,
    shrink: () => Zn,
    shrinklist: () => Yn,
    shuffle: () => lw,
    signal: () => j2,
    silence: () => q2,
    sine: () => Af,
    sine2: () => Te2,
    sinefold: () => hy,
    size: () => pl,
    slice: () => ss,
    slide: () => Ia,
    slow: () => Td,
    slowChunk: () => wm,
    slowcat: () => Z2,
    slowcatPrime: () => fe2,
    slowchunk: () => ym,
    smear: () => Kl,
    soft: () => iy,
    sol2note: () => uh,
    someCycles: () => Mw,
    someCyclesBy: () => zw,
    sometimes: () => Ow,
    sometimesBy: () => Bw,
    songPtr: () => ip,
    sound: () => as,
    source: () => Qs,
    sparsity: () => Cd,
    speak: () => Vw,
    speed: () => ye2,
    splice: () => Ym,
    splitAt: () => ue2,
    spread: () => Zu,
    square: () => Tf,
    square2: () => Xy,
    squeeze: () => Ry,
    squeezeBind: () => zh,
    squiz: () => Tl,
    src: () => Us,
    stack: () => z,
    stackBy: () => vh,
    stackCentre: () => $n,
    stackLeft: () => jn,
    stackRight: () => Jn,
    steady: () => Gy,
    stepBind: () => Mh,
    stepalt: () => Dn,
    stepcat: () => $2,
    steps: () => Um,
    stepsPerOctave: () => Ca,
    stretch: () => Sl,
    striate: () => Km,
    stringifyValues: () => ae,
    struct: () => Ah,
    strudelScope: () => le,
    stut: () => um,
    stutWith: () => om,
    stutwith: () => cm,
    sub: () => Nh,
    superimpose: () => Th,
    sus: () => qc,
    sustain: () => kc,
    sustainpedal: () => zl,
    swing: () => Vd,
    swingBy: () => Id,
    sysex: () => Ip,
    sysexdata: () => Hp,
    sysexid: () => Vp,
    sz: () => fl,
    take: () => Gn,
    time: () => ew,
    timeCat: () => ns,
    timecat: () => Jm,
    timeline: () => Cy,
    toBipolar: () => ud,
    tokenizeNote: () => Ue2,
    tour: () => ts,
    transient: () => rf,
    trem: () => Fc,
    tremolo: () => Wc,
    tremolodepth: () => Vc,
    tremolophase: () => Dc,
    tremoloshape: () => Gc,
    tremoloskew: () => Hc,
    tremolosync: () => Ic,
    tri: () => Ky,
    tri2: () => Yy,
    triode: () => jl,
    tsdelay: () => Dl,
    uid: () => up,
    undegrade: () => xw,
    undegradeBy: () => Cw,
    unicodeToBase64: () => wn,
    uniq: () => ah,
    uniqsort: () => lh,
    uniqsortr: () => yn,
    unison: () => Yu,
    unit: () => Al,
    useRNG: () => cw,
    v: () => xu,
    val: () => ap,
    valueToMidi: () => Zf,
    vel: () => tr,
    velocity: () => Zs,
    vib: () => Tu,
    vibmod: () => Ou,
    vibrato: () => Cu,
    vmod: () => zu,
    voice: () => Ha,
    vowel: () => Cl,
    warp: () => Cs,
    warpatt: () => Os,
    warpattack: () => Bs,
    warpdc: () => Rs,
    warpdec: () => Ms,
    warpdecay: () => zs,
    warpdepth: () => Ns,
    warpenv: () => Ds,
    warpmode: () => Fs,
    warprate: () => $s,
    warprel: () => Js,
    warprelease: () => js,
    warpshape: () => Ls,
    warpskew: () => Ws,
    warpsus: () => Es,
    warpsustain: () => Ps,
    warpsync: () => Gs,
    waveloss: () => xl,
    wavetablePhaseRand: () => Hs,
    wavetablePosition: () => ps,
    wavetableWarp: () => xs,
    wavetableWarpMode: () => Is,
    wchoose: () => _w,
    wchooseCycles: () => If,
    when: () => Gd,
    whenKey: () => Lw,
    withSeed: () => Lf,
    withValue: () => Ch,
    within: () => Pm,
    worklet: () => wy,
    wrandcat: () => vw,
    wt: () => ls,
    wtatt: () => ds,
    wtattack: () => hs,
    wtdc: () => As,
    wtdec: () => ys,
    wtdecay: () => ms,
    wtdepth: () => qs,
    wtenv: () => fs,
    wtphaserand: () => Vs,
    wtrate: () => vs,
    wtrel: () => _s,
    wtrelease: () => bs,
    wtshape: () => Ss,
    wtskew: () => Ts,
    wtsus: () => gs,
    wtsustain: () => ws,
    wtsync: () => ks,
    xfade: () => rs,
    xsdelay: () => Hl,
    zcrush: () => kp,
    zdelay: () => qp,
    zip: () => es,
    zipWith: () => Pt2,
    zmod: () => vp,
    znoise: () => _p,
    zoom: () => Jd,
    zoomArc: () => $d,
    zoomarc: () => Nd,
    zrand: () => mp,
    zzfx: () => Sp
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/fraction.js/dist/fraction.mjs
  if (typeof BigInt === "undefined") BigInt = function(n2) {
    if (isNaN(n2)) throw new Error("");
    return n2;
  };
  var C_ZERO = BigInt(0);
  var C_ONE = BigInt(1);
  var C_TWO = BigInt(2);
  var C_THREE = BigInt(3);
  var C_FIVE = BigInt(5);
  var C_TEN = BigInt(10);
  var MAX_INTEGER = BigInt(Number.MAX_SAFE_INTEGER);
  var MAX_CYCLE_LEN = 2e3;
  var P = {
    "s": C_ONE,
    "n": C_ZERO,
    "d": C_ONE
  };
  function assign(n2, s2) {
    try {
      n2 = BigInt(n2);
    } catch (e) {
      throw InvalidParameter();
    }
    return n2 * s2;
  }
  function ifloor(x2) {
    return typeof x2 === "bigint" ? x2 : Math.floor(x2);
  }
  function newFraction(n2, d2) {
    if (d2 === C_ZERO) {
      throw DivisionByZero();
    }
    const f4 = Object.create(Fraction.prototype);
    f4["s"] = n2 < C_ZERO ? -C_ONE : C_ONE;
    n2 = n2 < C_ZERO ? -n2 : n2;
    const a2 = gcd(n2, d2);
    f4["n"] = n2 / a2;
    f4["d"] = d2 / a2;
    return f4;
  }
  var FACTORSTEPS = [C_TWO * C_TWO, C_TWO, C_TWO * C_TWO, C_TWO, C_TWO * C_TWO, C_TWO * C_THREE, C_TWO, C_TWO * C_THREE];
  function factorize(n2) {
    const factors = /* @__PURE__ */ Object.create(null);
    if (n2 <= C_ONE) {
      factors[n2] = C_ONE;
      return factors;
    }
    const add2 = (p2) => {
      factors[p2] = (factors[p2] || C_ZERO) + C_ONE;
    };
    while (n2 % C_TWO === C_ZERO) {
      add2(C_TWO);
      n2 /= C_TWO;
    }
    while (n2 % C_THREE === C_ZERO) {
      add2(C_THREE);
      n2 /= C_THREE;
    }
    while (n2 % C_FIVE === C_ZERO) {
      add2(C_FIVE);
      n2 /= C_FIVE;
    }
    for (let si3 = 0, p2 = C_TWO + C_FIVE; p2 * p2 <= n2; ) {
      while (n2 % p2 === C_ZERO) {
        add2(p2);
        n2 /= p2;
      }
      p2 += FACTORSTEPS[si3];
      si3 = si3 + 1 & 7;
    }
    if (n2 > C_ONE) add2(n2);
    return factors;
  }
  var parse = function(p12, p2) {
    let n2 = C_ZERO, d2 = C_ONE, s2 = C_ONE;
    if (p12 === void 0 || p12 === null) {
    } else if (p2 !== void 0) {
      if (typeof p12 === "bigint") {
        n2 = p12;
      } else if (isNaN(p12)) {
        throw InvalidParameter();
      } else if (p12 % 1 !== 0) {
        throw NonIntegerParameter();
      } else {
        n2 = BigInt(p12);
      }
      if (typeof p2 === "bigint") {
        d2 = p2;
      } else if (isNaN(p2)) {
        throw InvalidParameter();
      } else if (p2 % 1 !== 0) {
        throw NonIntegerParameter();
      } else {
        d2 = BigInt(p2);
      }
      s2 = n2 * d2;
    } else if (typeof p12 === "object") {
      if ("d" in p12 && "n" in p12) {
        n2 = BigInt(p12["n"]);
        d2 = BigInt(p12["d"]);
        if ("s" in p12)
          n2 *= BigInt(p12["s"]);
      } else if (0 in p12) {
        n2 = BigInt(p12[0]);
        if (1 in p12)
          d2 = BigInt(p12[1]);
      } else if (typeof p12 === "bigint") {
        n2 = p12;
      } else {
        throw InvalidParameter();
      }
      s2 = n2 * d2;
    } else if (typeof p12 === "number") {
      if (isNaN(p12)) {
        throw InvalidParameter();
      }
      if (p12 < 0) {
        s2 = -C_ONE;
        p12 = -p12;
      }
      if (p12 % 1 === 0) {
        n2 = BigInt(p12);
      } else {
        let z4 = 1;
        let A4 = 0, B5 = 1;
        let C6 = 1, D4 = 1;
        let N5 = 1e7;
        if (p12 >= 1) {
          z4 = 10 ** Math.floor(1 + Math.log10(p12));
          p12 /= z4;
        }
        while (B5 <= N5 && D4 <= N5) {
          let M2 = (A4 + C6) / (B5 + D4);
          if (p12 === M2) {
            if (B5 + D4 <= N5) {
              n2 = A4 + C6;
              d2 = B5 + D4;
            } else if (D4 > B5) {
              n2 = C6;
              d2 = D4;
            } else {
              n2 = A4;
              d2 = B5;
            }
            break;
          } else {
            if (p12 > M2) {
              A4 += C6;
              B5 += D4;
            } else {
              C6 += A4;
              D4 += B5;
            }
            if (B5 > N5) {
              n2 = C6;
              d2 = D4;
            } else {
              n2 = A4;
              d2 = B5;
            }
          }
        }
        n2 = BigInt(n2) * BigInt(z4);
        d2 = BigInt(d2);
      }
    } else if (typeof p12 === "string") {
      let ndx = 0;
      let v2 = C_ZERO, w5 = C_ZERO, x2 = C_ZERO, y3 = C_ONE, z4 = C_ONE;
      let match = p12.replace(/_/g, "").match(/\d+|./g);
      if (match === null)
        throw InvalidParameter();
      if (match[ndx] === "-") {
        s2 = -C_ONE;
        ndx++;
      } else if (match[ndx] === "+") {
        ndx++;
      }
      if (match.length === ndx + 1) {
        w5 = assign(match[ndx++], s2);
      } else if (match[ndx + 1] === "." || match[ndx] === ".") {
        if (match[ndx] !== ".") {
          v2 = assign(match[ndx++], s2);
        }
        ndx++;
        if (ndx + 1 === match.length || match[ndx + 1] === "(" && match[ndx + 3] === ")" || match[ndx + 1] === "'" && match[ndx + 3] === "'") {
          w5 = assign(match[ndx], s2);
          y3 = C_TEN ** BigInt(match[ndx].length);
          ndx++;
        }
        if (match[ndx] === "(" && match[ndx + 2] === ")" || match[ndx] === "'" && match[ndx + 2] === "'") {
          x2 = assign(match[ndx + 1], s2);
          z4 = C_TEN ** BigInt(match[ndx + 1].length) - C_ONE;
          ndx += 3;
        }
      } else if (match[ndx + 1] === "/" || match[ndx + 1] === ":") {
        w5 = assign(match[ndx], s2);
        y3 = assign(match[ndx + 2], C_ONE);
        ndx += 3;
      } else if (match[ndx + 3] === "/" && match[ndx + 1] === " ") {
        v2 = assign(match[ndx], s2);
        w5 = assign(match[ndx + 2], s2);
        y3 = assign(match[ndx + 4], C_ONE);
        ndx += 5;
      }
      if (match.length <= ndx) {
        d2 = y3 * z4;
        s2 = /* void */
        n2 = x2 + d2 * v2 + z4 * w5;
      } else {
        throw InvalidParameter();
      }
    } else if (typeof p12 === "bigint") {
      n2 = p12;
      s2 = p12;
      d2 = C_ONE;
    } else {
      throw InvalidParameter();
    }
    if (d2 === C_ZERO) {
      throw DivisionByZero();
    }
    P["s"] = s2 < C_ZERO ? -C_ONE : C_ONE;
    P["n"] = n2 < C_ZERO ? -n2 : n2;
    P["d"] = d2 < C_ZERO ? -d2 : d2;
  };
  function modpow(b2, e, m3) {
    let r = C_ONE;
    for (; e > C_ZERO; b2 = b2 * b2 % m3, e >>= C_ONE) {
      if (e & C_ONE) {
        r = r * b2 % m3;
      }
    }
    return r;
  }
  function cycleLen(n2, d2) {
    for (; d2 % C_TWO === C_ZERO; d2 /= C_TWO) {
    }
    for (; d2 % C_FIVE === C_ZERO; d2 /= C_FIVE) {
    }
    if (d2 === C_ONE)
      return C_ZERO;
    let rem = C_TEN % d2;
    let t = 1;
    for (; rem !== C_ONE; t++) {
      rem = rem * C_TEN % d2;
      if (t > MAX_CYCLE_LEN)
        return C_ZERO;
    }
    return BigInt(t);
  }
  function cycleStart(n2, d2, len) {
    let rem1 = C_ONE;
    let rem2 = modpow(C_TEN, len, d2);
    for (let t = 0; t < 300; t++) {
      if (rem1 === rem2)
        return BigInt(t);
      rem1 = rem1 * C_TEN % d2;
      rem2 = rem2 * C_TEN % d2;
    }
    return 0;
  }
  function gcd(a2, b2) {
    if (!a2)
      return b2;
    if (!b2)
      return a2;
    while (1) {
      a2 %= b2;
      if (!a2)
        return b2;
      b2 %= a2;
      if (!b2)
        return a2;
    }
  }
  function Fraction(a2, b2) {
    parse(a2, b2);
    if (this instanceof Fraction) {
      a2 = gcd(P["d"], P["n"]);
      this["s"] = P["s"];
      this["n"] = P["n"] / a2;
      this["d"] = P["d"] / a2;
    } else {
      return newFraction(P["s"] * P["n"], P["d"]);
    }
  }
  var DivisionByZero = function() {
    return new Error("Division by Zero");
  };
  var InvalidParameter = function() {
    return new Error("Invalid argument");
  };
  var NonIntegerParameter = function() {
    return new Error("Parameters must be integer");
  };
  Fraction.prototype = {
    "s": C_ONE,
    "n": C_ZERO,
    "d": C_ONE,
    /**
     * Calculates the absolute value
     *
     * Ex: new Fraction(-4).abs() => 4
     **/
    "abs": function() {
      return newFraction(this["n"], this["d"]);
    },
    /**
     * Inverts the sign of the current fraction
     *
     * Ex: new Fraction(-4).neg() => 4
     **/
    "neg": function() {
      return newFraction(-this["s"] * this["n"], this["d"]);
    },
    /**
     * Adds two rational numbers
     *
     * Ex: new Fraction({n: 2, d: 3}).add("14.9") => 467 / 30
     **/
    "add": function(a2, b2) {
      parse(a2, b2);
      return newFraction(
        this["s"] * this["n"] * P["d"] + P["s"] * this["d"] * P["n"],
        this["d"] * P["d"]
      );
    },
    /**
     * Subtracts two rational numbers
     *
     * Ex: new Fraction({n: 2, d: 3}).add("14.9") => -427 / 30
     **/
    "sub": function(a2, b2) {
      parse(a2, b2);
      return newFraction(
        this["s"] * this["n"] * P["d"] - P["s"] * this["d"] * P["n"],
        this["d"] * P["d"]
      );
    },
    /**
     * Multiplies two rational numbers
     *
     * Ex: new Fraction("-17.(345)").mul(3) => 5776 / 111
     **/
    "mul": function(a2, b2) {
      parse(a2, b2);
      return newFraction(
        this["s"] * P["s"] * this["n"] * P["n"],
        this["d"] * P["d"]
      );
    },
    /**
     * Divides two rational numbers
     *
     * Ex: new Fraction("-17.(345)").inverse().div(3)
     **/
    "div": function(a2, b2) {
      parse(a2, b2);
      return newFraction(
        this["s"] * P["s"] * this["n"] * P["d"],
        this["d"] * P["n"]
      );
    },
    /**
     * Clones the actual object
     *
     * Ex: new Fraction("-17.(345)").clone()
     **/
    "clone": function() {
      return newFraction(this["s"] * this["n"], this["d"]);
    },
    /**
     * Calculates the modulo of two rational numbers - a more precise fmod
     *
     * Ex: new Fraction('4.(3)').mod([7, 8]) => (13/3) % (7/8) = (5/6)
     * Ex: new Fraction(20, 10).mod().equals(0) ? "is Integer"
     **/
    "mod": function(a2, b2) {
      if (a2 === void 0) {
        return newFraction(this["s"] * this["n"] % this["d"], C_ONE);
      }
      parse(a2, b2);
      if (C_ZERO === P["n"] * this["d"]) {
        throw DivisionByZero();
      }
      return newFraction(
        this["s"] * (P["d"] * this["n"]) % (P["n"] * this["d"]),
        P["d"] * this["d"]
      );
    },
    /**
     * Calculates the fractional gcd of two rational numbers
     *
     * Ex: new Fraction(5,8).gcd(3,7) => 1/56
     */
    "gcd": function(a2, b2) {
      parse(a2, b2);
      return newFraction(gcd(P["n"], this["n"]) * gcd(P["d"], this["d"]), P["d"] * this["d"]);
    },
    /**
     * Calculates the fractional lcm of two rational numbers
     *
     * Ex: new Fraction(5,8).lcm(3,7) => 15
     */
    "lcm": function(a2, b2) {
      parse(a2, b2);
      if (P["n"] === C_ZERO && this["n"] === C_ZERO) {
        return newFraction(C_ZERO, C_ONE);
      }
      return newFraction(P["n"] * this["n"], gcd(P["n"], this["n"]) * gcd(P["d"], this["d"]));
    },
    /**
     * Gets the inverse of the fraction, means numerator and denominator are exchanged
     *
     * Ex: new Fraction([-3, 4]).inverse() => -4 / 3
     **/
    "inverse": function() {
      return newFraction(this["s"] * this["d"], this["n"]);
    },
    /**
     * Calculates the fraction to some integer exponent
     *
     * Ex: new Fraction(-1,2).pow(-3) => -8
     */
    "pow": function(a2, b2) {
      parse(a2, b2);
      if (P["d"] === C_ONE) {
        if (P["s"] < C_ZERO) {
          return newFraction((this["s"] * this["d"]) ** P["n"], this["n"] ** P["n"]);
        } else {
          return newFraction((this["s"] * this["n"]) ** P["n"], this["d"] ** P["n"]);
        }
      }
      if (this["s"] < C_ZERO) return null;
      let N5 = factorize(this["n"]);
      let D4 = factorize(this["d"]);
      let n2 = C_ONE;
      let d2 = C_ONE;
      for (let k6 in N5) {
        if (k6 === "1") continue;
        if (k6 === "0") {
          n2 = C_ZERO;
          break;
        }
        N5[k6] *= P["n"];
        if (N5[k6] % P["d"] === C_ZERO) {
          N5[k6] /= P["d"];
        } else return null;
        n2 *= BigInt(k6) ** N5[k6];
      }
      for (let k6 in D4) {
        if (k6 === "1") continue;
        D4[k6] *= P["n"];
        if (D4[k6] % P["d"] === C_ZERO) {
          D4[k6] /= P["d"];
        } else return null;
        d2 *= BigInt(k6) ** D4[k6];
      }
      if (P["s"] < C_ZERO) {
        return newFraction(d2, n2);
      }
      return newFraction(n2, d2);
    },
    /**
     * Calculates the logarithm of a fraction to a given rational base
     *
     * Ex: new Fraction(27, 8).log(9, 4) => 3/2
     */
    "log": function(a2, b2) {
      parse(a2, b2);
      if (this["s"] <= C_ZERO || P["s"] <= C_ZERO) return null;
      const allPrimes = /* @__PURE__ */ Object.create(null);
      const baseFactors = factorize(P["n"]);
      const T12 = factorize(P["d"]);
      const numberFactors = factorize(this["n"]);
      const T22 = factorize(this["d"]);
      for (const prime in T12) {
        baseFactors[prime] = (baseFactors[prime] || C_ZERO) - T12[prime];
      }
      for (const prime in T22) {
        numberFactors[prime] = (numberFactors[prime] || C_ZERO) - T22[prime];
      }
      for (const prime in baseFactors) {
        if (prime === "1") continue;
        allPrimes[prime] = true;
      }
      for (const prime in numberFactors) {
        if (prime === "1") continue;
        allPrimes[prime] = true;
      }
      let retN = null;
      let retD = null;
      for (const prime in allPrimes) {
        const baseExponent = baseFactors[prime] || C_ZERO;
        const numberExponent = numberFactors[prime] || C_ZERO;
        if (baseExponent === C_ZERO) {
          if (numberExponent !== C_ZERO) {
            return null;
          }
          continue;
        }
        let curN = numberExponent;
        let curD = baseExponent;
        const gcdValue = gcd(curN, curD);
        curN /= gcdValue;
        curD /= gcdValue;
        if (retN === null && retD === null) {
          retN = curN;
          retD = curD;
        } else if (curN * retD !== retN * curD) {
          return null;
        }
      }
      return retN !== null && retD !== null ? newFraction(retN, retD) : null;
    },
    /**
     * Check if two rational numbers are the same
     *
     * Ex: new Fraction(19.6).equals([98, 5]);
     **/
    "equals": function(a2, b2) {
      parse(a2, b2);
      return this["s"] * this["n"] * P["d"] === P["s"] * P["n"] * this["d"];
    },
    /**
     * Check if this rational number is less than another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    "lt": function(a2, b2) {
      parse(a2, b2);
      return this["s"] * this["n"] * P["d"] < P["s"] * P["n"] * this["d"];
    },
    /**
     * Check if this rational number is less than or equal another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    "lte": function(a2, b2) {
      parse(a2, b2);
      return this["s"] * this["n"] * P["d"] <= P["s"] * P["n"] * this["d"];
    },
    /**
     * Check if this rational number is greater than another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    "gt": function(a2, b2) {
      parse(a2, b2);
      return this["s"] * this["n"] * P["d"] > P["s"] * P["n"] * this["d"];
    },
    /**
     * Check if this rational number is greater than or equal another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    "gte": function(a2, b2) {
      parse(a2, b2);
      return this["s"] * this["n"] * P["d"] >= P["s"] * P["n"] * this["d"];
    },
    /**
     * Compare two rational numbers
     * < 0 iff this < that
     * > 0 iff this > that
     * = 0 iff this = that
     *
     * Ex: new Fraction(19.6).compare([98, 5]);
     **/
    "compare": function(a2, b2) {
      parse(a2, b2);
      let t = this["s"] * this["n"] * P["d"] - P["s"] * P["n"] * this["d"];
      return (C_ZERO < t) - (t < C_ZERO);
    },
    /**
     * Calculates the ceil of a rational number
     *
     * Ex: new Fraction('4.(3)').ceil() => (5 / 1)
     **/
    "ceil": function(places) {
      places = C_TEN ** BigInt(places || 0);
      return newFraction(
        ifloor(this["s"] * places * this["n"] / this["d"]) + (places * this["n"] % this["d"] > C_ZERO && this["s"] >= C_ZERO ? C_ONE : C_ZERO),
        places
      );
    },
    /**
     * Calculates the floor of a rational number
     *
     * Ex: new Fraction('4.(3)').floor() => (4 / 1)
     **/
    "floor": function(places) {
      places = C_TEN ** BigInt(places || 0);
      return newFraction(
        ifloor(this["s"] * places * this["n"] / this["d"]) - (places * this["n"] % this["d"] > C_ZERO && this["s"] < C_ZERO ? C_ONE : C_ZERO),
        places
      );
    },
    /**
     * Rounds a rational numbers
     *
     * Ex: new Fraction('4.(3)').round() => (4 / 1)
     **/
    "round": function(places) {
      places = C_TEN ** BigInt(places || 0);
      return newFraction(
        ifloor(this["s"] * places * this["n"] / this["d"]) + this["s"] * ((this["s"] >= C_ZERO ? C_ONE : C_ZERO) + C_TWO * (places * this["n"] % this["d"]) > this["d"] ? C_ONE : C_ZERO),
        places
      );
    },
    /**
      * Rounds a rational number to a multiple of another rational number
      *
      * Ex: new Fraction('0.9').roundTo("1/8") => 7 / 8
      **/
    "roundTo": function(a2, b2) {
      parse(a2, b2);
      const n2 = this["n"] * P["d"];
      const d2 = this["d"] * P["n"];
      const r = n2 % d2;
      let k6 = ifloor(n2 / d2);
      if (r + r >= d2) {
        k6++;
      }
      return newFraction(this["s"] * k6 * P["n"], P["d"]);
    },
    /**
     * Check if two rational numbers are divisible
     *
     * Ex: new Fraction(19.6).divisible(1.5);
     */
    "divisible": function(a2, b2) {
      parse(a2, b2);
      if (P["n"] === C_ZERO) return false;
      return this["n"] * P["d"] % (P["n"] * this["d"]) === C_ZERO;
    },
    /**
     * Returns a decimal representation of the fraction
     *
     * Ex: new Fraction("100.'91823'").valueOf() => 100.91823918239183
     **/
    "valueOf": function() {
      return Number(this["s"] * this["n"]) / Number(this["d"]);
    },
    /**
     * Creates a string representation of a fraction with all digits
     *
     * Ex: new Fraction("100.'91823'").toString() => "100.(91823)"
     **/
    "toString": function(dec = 15) {
      let N5 = this["n"];
      let D4 = this["d"];
      let cycLen = cycleLen(N5, D4);
      let cycOff = cycleStart(N5, D4, cycLen);
      let str = this["s"] < C_ZERO ? "-" : "";
      str += ifloor(N5 / D4);
      N5 %= D4;
      N5 *= C_TEN;
      if (N5)
        str += ".";
      if (cycLen) {
        for (let i = cycOff; i--; ) {
          str += ifloor(N5 / D4);
          N5 %= D4;
          N5 *= C_TEN;
        }
        str += "(";
        for (let i = cycLen; i--; ) {
          str += ifloor(N5 / D4);
          N5 %= D4;
          N5 *= C_TEN;
        }
        str += ")";
      } else {
        for (let i = dec; N5 && i--; ) {
          str += ifloor(N5 / D4);
          N5 %= D4;
          N5 *= C_TEN;
        }
      }
      return str;
    },
    /**
     * Returns a string-fraction representation of a Fraction object
     *
     * Ex: new Fraction("1.'3'").toFraction() => "4 1/3"
     **/
    "toFraction": function(showMixed = false) {
      let n2 = this["n"];
      let d2 = this["d"];
      let str = this["s"] < C_ZERO ? "-" : "";
      if (d2 === C_ONE) {
        str += n2;
      } else {
        const whole = ifloor(n2 / d2);
        if (showMixed && whole > C_ZERO) {
          str += whole;
          str += " ";
          n2 %= d2;
        }
        str += n2;
        str += "/";
        str += d2;
      }
      return str;
    },
    /**
     * Returns a latex representation of a Fraction object
     *
     * Ex: new Fraction("1.'3'").toLatex() => "\frac{4}{3}"
     **/
    "toLatex": function(showMixed = false) {
      let n2 = this["n"];
      let d2 = this["d"];
      let str = this["s"] < C_ZERO ? "-" : "";
      if (d2 === C_ONE) {
        str += n2;
      } else {
        const whole = ifloor(n2 / d2);
        if (showMixed && whole > C_ZERO) {
          str += whole;
          n2 %= d2;
        }
        str += "\\frac{";
        str += n2;
        str += "}{";
        str += d2;
        str += "}";
      }
      return str;
    },
    /**
     * Returns an array of continued fraction elements
     *
     * Ex: new Fraction("7/8").toContinued() => [0,1,7]
     */
    "toContinued": function() {
      let a2 = this["n"];
      let b2 = this["d"];
      const res = [];
      while (b2) {
        res.push(ifloor(a2 / b2));
        const t = a2 % b2;
        a2 = b2;
        b2 = t;
      }
      return res;
    },
    "simplify": function(eps = 1e-3) {
      const ieps = BigInt(Math.ceil(1 / eps));
      const thisABS = this["abs"]();
      const cont = thisABS["toContinued"]();
      for (let i = 1; i < cont.length; i++) {
        let s2 = newFraction(cont[i - 1], C_ONE);
        for (let k6 = i - 2; k6 >= 0; k6--) {
          s2 = s2["inverse"]()["add"](cont[k6]);
        }
        let t = s2["sub"](thisABS);
        if (t["n"] * ieps < t["d"]) {
          return s2["mul"](this["s"]);
        }
      }
      return this;
    }
  };

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@kabelsalat/web/dist/index.mjs
  function W(e, t) {
    if (t || (t = "assertion failed"), !e)
      throw new Error(t);
  }
  var c = class {
    constructor(t, i) {
      this.type = t, i !== void 0 && (this.value = i), this.ins = [];
    }
    static parseInput(t, i) {
      if (typeof t == "function") {
        if (!i)
          throw new Error(
            "tried to parse function input without without passing node.."
          );
        return t(i);
      }
      return typeof t == "object" ? t : typeof t == "number" && !isNaN(t) || typeof t == "string" ? f(t) : (console.log(
        `invalid input type "${typeof t}" for node of type "${i.type}", falling back to 0. The input was:`,
        t
      ), 0);
    }
  };
  var x = (e, t) => new c(e, t);
  var y = /* @__PURE__ */ new Map();
  var Z = "poly";
  var Y = "exit";
  c.prototype.inherit = function(e) {
    return e.inputOf && (this.inputOf = e.inputOf), e.outputOf && (this.outputOf = e.outputOf), this;
  };
  c.prototype.toObject = function() {
    return JSON.parse(JSON.stringify(this));
  };
  c.prototype.stringify = function() {
    return JSON.stringify(this, null, 2).replaceAll('"', "'");
  };
  function F(e, ...t) {
    let i = 1;
    if (t = t.map((l2) => {
      if (Array.isArray(l2)) {
        if (l2.length === 1)
          return l2[0];
        l2 = new c(Z).withIns(...l2);
      }
      if (typeof l2 == "function") {
        const o = l2(new c("peek"));
        o.type === Z && (i = Math.max(o.ins.length, i));
      }
      return l2.type === Z && (i = Math.max(l2.ins.length, i)), l2;
    }), i === 1) {
      const l2 = x(e);
      return l2.withIns(...t.map((o) => c.parseInput(o, l2)));
    }
    if (e === Y) {
      const l2 = t.map((o) => o.type === Z ? o.ins.map((d2) => c.parseInput(d2).inherit(d2)) : o).flat();
      return x(Y).withIns(...l2);
    }
    const n2 = Array.from({ length: i }, (l2, o) => {
      const d2 = new c(e), G4 = t.map((p2) => p2.type === Z ? c.parseInput(p2.ins[o % p2.ins.length], d2).inherit(p2) : (p2 = c.parseInput(p2, d2), p2.type === Z && (p2 = p2.ins[o]), p2));
      return d2.withIns(...G4);
    });
    return new c(Z).withIns(...n2);
  }
  function oe(e, t) {
    const i = y.get(e);
    return i?.ins?.[t] ? i.ins[t].name : "";
  }
  var a = (e, t) => u(e, (...i) => F(e, ...i), t);
  y.set("register", {
    tags: ["meta"],
    graph: false,
    description: "Registers a new Node function. Sets it on the prototype + returns the function itself. Like `module` but doesn't hide complexity in graph viz.",
    examples: [
      `let kick = register('kick', gate => gate.adsr(0,.11,0,.11)
.apply(env => env.mul(env)
  .mul(158)
  .sine(env)
  .distort(.85)
))
impulse(2).kick().out()`
    ]
  });
  var u = (e, t, i) => (i && y.set(e, i), c.prototype[e] = function(...n2) {
    return t(this, ...n2);
  }, c.prototype["_" + e] = function() {
    return this;
  }, t);
  y.set("module", {
    tags: ["meta"],
    graph: true,
    description: "Creates a module. Like `register`, but the graph viz will hide the internal complexity of the module.",
    examples: [
      `let kick = module('kick', gate => gate.adsr(0,.11,0,.11)
.apply(env => env.mul(env)
  .mul(158)
  .sine(env)
  .distort(.85)
))
impulse(2).kick().out()`
    ]
  });
  var de = 0;
  function g(e, t, i) {
    return u(
      e,
      (...n2) => {
        const l2 = de++;
        return n2 = n2.map(
          (o, d2) => c.parseInput(o).asModuleInput?.(e, l2, d2)
        ), t(...n2).asModuleOutput?.(e, l2);
      },
      i
    );
  }
  y.set("n", {
    tags: ["math"],
    description: "Constant value node. Turns a number into a Node.",
    ins: [{ name: "value", default: 0 }]
  });
  function f(e) {
    return Array.isArray(e) ? poly(...e.map((t) => f(t))) : typeof e == "object" ? e : x("n", e);
  }
  y.set("out", {
    tags: ["meta"],
    description: "Sends the node to the audio output"
  });
  y.set("withIns", {
    internal: true,
    tags: ["innards"],
    description: "Sets the inputs of a node. Returns the node itself",
    ins: [{ name: "in", dynamic: true }]
  });
  c.prototype.withIns = function(...e) {
    return this.ins = e, this;
  };
  y.set("flatten", {
    internal: true,
    tags: ["innards"],
    description: "Flattens the node to a list of all nodes in the graph, where each Node's ins are now indices"
  });
  c.prototype.flatten = function() {
    return pe(this);
  };
  y.set("apply", {
    graph: true,
    tags: ["meta"],
    description: "Applies the given function to the Node. Useful when a node has to be used multiple times.",
    examples: [
      `impulse(4)
.apply(imp=>imp
  .seq(110,220,330,440)
  .sine()
  .mul( imp.ad(.1,.1) )
).out()`
    ]
  });
  c.prototype.apply = function(e) {
    return e(this);
  };
  y.set("clone", {
    internal: true,
    tags: ["innards"],
    description: "Clones the node"
  });
  c.prototype.clone = function() {
    return new c(this.type, this.value).withIns(...this.ins);
  };
  y.set("map", {
    tags: ["meta"],
    description: "Applies the given function to all ins if it's poly node. Otherwise it applies the function to itself.",
    examples: [
      `n([110,220,330])
.map( freq=>freq.mul([1,1.007]).saw().mix() )
.mix(2).mul(.5).out()`
    ]
  });
  c.prototype.map = function(e) {
    return this.type !== "poly" ? e(this) : poly(...this.ins.map(e));
  };
  c.prototype.channel = function(e) {
    return this.type !== "poly" ? this : this.ins[e % this.ins.length];
  };
  y.set("select", {
    tags: ["meta"],
    graph: true,
    description: "Find the first occurence of the given type up in the graph and returns the match. Useful to exit a feedback loop at another point.",
    examples: [
      `sine(220).mul(impulse(1).ad(.001,.2))
.add( x=>x.delay(.2).mul(.8) )
.select('delay').out()
`
    ]
  });
  c.prototype.select = function(e) {
    for (let t of this.ins) {
      if (t.type === e)
        return t;
      const i = t.select(e);
      if (i)
        return i;
    }
  };
  y.set("debug", {
    tags: ["meta"],
    description: "Logs the node to the console"
  });
  c.prototype.debug = function(e = (t) => t) {
    return console.log(e(this)), this;
  };
  function ce(e) {
    const t = modules.get(e), i = Array.from(
      { length: t.length },
      (l2, o) => x(`$INPUT${o}`)
    ), n2 = t(...i);
    return JSON.stringify(n2, null, 2);
  }
  function pe(e) {
    const t = [];
    return S(e, (i) => (t.push(i), i)), t.map((i) => {
      let n2 = {
        ...i,
        type: i.type,
        ins: i.ins.map((l2) => t.indexOf(l2) + "")
      };
      return i.value !== void 0 && (n2.value = i.value), i.to !== void 0 && (n2.to = t.indexOf(i.to)), n2;
    });
  }
  var J = a("exit", { internal: true });
  function j(e, t) {
    let i = [];
    const n2 = u("out", function(o, d2 = [0, 1]) {
      return i.push(o.output(d2)), o;
    });
    return t ? (t.out = n2, Function(...Object.keys(t), e)(...Object.values(t))) : (globalThis.out = n2, Function(e)()), J(...i);
  }
  c.prototype.over = function(e) {
    return this.apply((t) => add(t, e(t)));
  };
  c.prototype.dfs = function(e, t) {
    return this.apply((i) => S(i, e, t));
  };
  c.prototype.apply2 = function(e) {
    return e(this, this);
  };
  var S = (e, t, i = []) => (e = t(e, i), i.push(e), e.ins = e.ins.map((n2) => i.includes(n2) ? n2 : S(n2, t, i)), e);
  c.prototype.asModuleInput = function(e, t, i) {
    return this.inputOf = this.inputOf || [], this.inputOf.push([e, t, i]), this;
  };
  c.prototype.asModuleOutput = function(e, t) {
    return this.outputOf = [e, t], this;
  };
  function T(e, t = {}) {
    const {
      log: i = false,
      lang: n2 = "js",
      fallbackType: l2 = "thru",
      constType: o = "n",
      getRegister: d2 = (h) => `r[${h}]`,
      getOutput: G4 = (h) => `o[${h}]`,
      getSource: p2 = (h) => `s[${h}]`
    } = t;
    i && console.log("compile", e);
    const m3 = ue(e);
    let r = [], R5 = (h) => m3[h].type !== o ? d2(h) : typeof m3[h].value == "string" ? `"${m3[h].value}"` : m3[h].value;
    const X = [];
    for (let h in m3) {
      const v2 = m3[h], I3 = m3[h].ins.map((ae3) => R5(m3.indexOf(ae3))), se3 = X.length;
      let b2 = y.get(v2.type);
      b2 || (console.warn(
        `unhandled node type "${m3[h].type}". falling back to "${l2}"`
      ), b2 = y.get(l2));
      const le3 = {
        vars: I3,
        node: v2,
        nodes: m3,
        id: h,
        ugenIndex: se3,
        ugen: b2.ugen,
        name: R5(h),
        lang: n2,
        getRegister: d2,
        getOutput: G4,
        getSource: p2
      };
      b2.compile && r.push(b2.compile(le3)), b2.ugen && X.push({ type: b2.ugen, inputs: I3 });
    }
    const z4 = r.join(`
`);
    return i && (console.log("compiled code:"), console.log(z4)), { src: z4, ugens: X, registers: m3.length };
  }
  c.prototype.compile = function(e) {
    return T(this, e);
  };
  function ue(e) {
    const t = [], i = /* @__PURE__ */ new Set();
    function n2(l2) {
      if (!(typeof l2 != "object" || i.has(l2))) {
        i.add(l2);
        for (let o in l2.ins)
          n2(l2.ins[o]);
        t.push(l2);
      }
    }
    return n2(e), t;
  }
  var U = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
    __proto__: null,
    compile: T
  }, Symbol.toStringTag, { value: "Module" }));
  var Q = class {
    constructor() {
      this._events = {};
    }
    on(t, i) {
      this._events[t] || (this._events[t] = []);
      let n2 = this._events[t];
      W(n2.indexOf(i) == -1), n2.push(i);
    }
    removeListener(t, i) {
      let n2 = this._events[t], l2 = n2.indexOf(i);
      l2 != -1 && n2.splice(l2, 1);
    }
    trigger(t, ...i) {
      let n2 = this._events[t] || [];
      for (let l2 = 0; l2 < n2.length; l2++)
        n2[l2].apply(null, i);
    }
  };
  var me = class extends Q {
    constructor(t = navigator) {
      super(), this.midiAccess = null, this.getMIDIAccess(t);
    }
    // Try to get MIDI access from the browser
    async getMIDIAccess(t) {
      if ("requestMIDIAccess" in t) {
        this.midiAccess = await t.requestMIDIAccess({ sysex: false }), console.log("got MIDI access");
        for (let i of this.midiAccess.inputs.values())
          i.state == "connected" && (i.onmidimessage = (n2) => this.trigger("midimessage", i.id, n2.data));
        this.midiAccess.onstatechange = (i) => {
          i.port.type == "input" && i.port.state == "connected" && (console.log(
            "MIDI device connected:",
            i.port.name,
            "PORT:",
            i.port.id
          ), i.port.onmidimessage = (n2) => this.trigger("midimessage", i.port.id, n2.data));
        };
      }
    }
    // Send a message to all MIDI devices
    broadcast(t, i) {
      if (midi)
        for (let n2 of this.midiAccess.outputs.values())
          n2.send(t, i);
    }
  };
  function re(e) {
    let t = e[0] & 240, i = (e[0] & 15) + 1;
    if (t == 176 && e.length == 3) {
      let n2 = e[1], o = e[2] / 127 * 2 - 1;
      return { type: "CC", channel: i, cc: n2, value: o };
    }
    if (t == 224 && e.length == 3) {
      let n2 = e[1], d2 = (e[2] << 7 | n2) / 16383 * 2 - 1;
      return { type: "PITCHBEND", channel: i, value: d2 };
    }
    if (t == 144 && e.length == 3) {
      let n2 = e[1], l2 = e[2] / 127;
      return { type: "NOTE_ON", channel: i, note: n2, velocity: l2 };
    }
    if (t == 128 && e.length == 3) {
      let n2 = e[1];
      return { type: "NOTE_ON", channel: i, note: n2, velocity: 0 };
    }
  }
  var he = class extends Q {
    constructor() {
      super(), this.attach();
    }
    attach() {
      typeof window < "u" && (this.handleMouseMove = (t) => {
        const i = t.clientX / document.body.clientWidth * 2 - 1, n2 = t.clientY / document.body.clientHeight * 2 - 1;
        this.trigger("move", i, n2);
      }, document.addEventListener("mousemove", this.handleMouseMove));
    }
    detach() {
      typeof window < "u" && document.removeEventListener("mousemove", this.handleMouseMove);
    }
  };
  var Ge = "data:text/javascript;base64,KGZ1bmN0aW9uKCl7InVzZSBzdHJpY3QiO2Z1bmN0aW9uIGcoaCx0KXtpZih0fHwodD0iYXNzZXJ0aW9uIGZhaWxlZCIpLCFoKXRocm93IG5ldyBFcnJvcih0KX1mdW5jdGlvbiBTKGgsdCxzKXtyZXR1cm4gaDw9MD90Omg+PTE/czp0K2gqKHMtdCl9ZnVuY3Rpb24gUChoLHQscyl7cmV0dXJuIGg8PXQ/MDpoPj1zPzE6cz09PXQ/MDooaC10KS8ocy10KX1mdW5jdGlvbiBFKGgsdCl7cmV0dXJuIGg8dD8oaC89dCxoK2gtaCpoLTEpOmg+MS10PyhoPShoLTEpL3QsaCpoK2graCsxKTowfWZ1bmN0aW9uIFUoaCl7cmV0dXJuIE1hdGguZmxvb3IoaCk9PT1ofWZ1bmN0aW9uIF8oaCl7cmV0dXJuIFUoaCkmJmg+MH1mdW5jdGlvbiBrKGgsdCl7dD1NYXRoLm1pbihNYXRoLm1heCh0LDApLDEpLHQtPS4wMTt2YXIgcz0yKnQvKDEtdCksZT0oMStzKSpoLygxK3MqTWF0aC5hYnMoaCkpO3JldHVybiBlfWZ1bmN0aW9uIHcoaCx0LHMpe3JldHVybiBoPj0xP3M6dCtoKihzLXQpfWZ1bmN0aW9uIFQoKXt0aGlzLnN0YXRlPSJvZmYiLHRoaXMuc3RhcnRUaW1lPTAsdGhpcy5zdGFydFZhbD0wfVQucHJvdG90eXBlLmV2YWw9ZnVuY3Rpb24oaCx0LHMsZSxpLG4pe3N3aXRjaCh0aGlzLnN0YXRlKXtjYXNlIm9mZiI6cmV0dXJuIHQ+MCYmKHRoaXMuc3RhdGU9ImF0dGFjayIsdGhpcy5zdGFydFRpbWU9aCx0aGlzLnN0YXJ0VmFsPTApLDA7Y2FzZSJhdHRhY2siOntsZXQgcj1oLXRoaXMuc3RhcnRUaW1lO3JldHVybiByPnM/KHRoaXMuc3RhdGU9ImRlY2F5Iix0aGlzLnN0YXJ0VGltZT1oLDEpOncoci9zLHRoaXMuc3RhcnRWYWwsMSl9Y2FzZSJkZWNheSI6e2xldCByPWgtdGhpcy5zdGFydFRpbWUsbD13KHIvZSwxLGkpO3JldHVybiB0PD0wPyh0aGlzLnN0YXRlPSJyZWxlYXNlIix0aGlzLnN0YXJ0VGltZT1oLHRoaXMuc3RhcnRWYWw9bCxsKTpyPmU/KHRoaXMuc3RhdGU9InN1c3RhaW4iLHRoaXMuc3RhcnRUaW1lPWgsaSk6bH1jYXNlInN1c3RhaW4iOnJldHVybiB0PD0wJiYodGhpcy5zdGF0ZT0icmVsZWFzZSIsdGhpcy5zdGFydFRpbWU9aCx0aGlzLnN0YXJ0VmFsPWkpLGk7Y2FzZSJyZWxlYXNlIjp7bGV0IHI9aC10aGlzLnN0YXJ0VGltZTtpZihyPm4pcmV0dXJuIHRoaXMuc3RhdGU9Im9mZiIsMDtsZXQgbD13KHIvbix0aGlzLnN0YXJ0VmFsLDApO3JldHVybiB0PjAmJih0aGlzLnN0YXRlPSJhdHRhY2siLHRoaXMuc3RhcnRUaW1lPWgsdGhpcy5zdGFydFZhbD1sKSxsfX10aHJvdyJpbnZhbGlkIGVudmVsb3BlIHN0YXRlIn07ZnVuY3Rpb24gdigpe3RoaXMuczA9MCx0aGlzLnMxPTB9di5wcm90b3R5cGUuYXBwbHk9ZnVuY3Rpb24oaCx0LHMpe2coIWlzTmFOKGgpLCJOYU4gdmFsdWUgZmVkIGluIFR3b1BvbGVGaWx0ZXIiKSx0PU1hdGgubWluKHQsMSkscz1NYXRoLm1heChzLDApO3ZhciBlPU1hdGgucG93KC41LCgxLXQpLy4xMjUpLGk9TWF0aC5wb3coLjUsKHMrLjEyNSkvLjEyNSksbj0xLWkqZSxyPXRoaXMuczAsbD10aGlzLnMxO3JldHVybiByPW4qci1lKmwrZSpoLGw9bipsK2UqcixoPWwsdGhpcy5zMD1yLHRoaXMuczE9bCxofTtsZXQgQT1jbGFzcyBDe2NvbnN0cnVjdG9yKHQscyl7dGhpcy5zYW1wbGVSYXRlPXQscz90aGlzLmJ1ZmZlcj1zLnNsaWNlKDApOih0aGlzLmJ1ZmZlcj1uZXcgRmxvYXQzMkFycmF5KDEwKnQpLHRoaXMuYnVmZmVyLmZpbGwoMCkpLHRoaXMud3JpdGVJZHg9MCx0aGlzLnJlYWRJZHg9MH1yZXNldCgpe3RoaXMuYnVmZmVyLmZpbGwoMCksdGhpcy53cml0ZUlkeD0wLHRoaXMucmVhZElkeD0wfWNsb25lKCl7Y29uc3QgdD1uZXcgQyh0aGlzLnNhbXBsZVJhdGUsdGhpcy5idWZmZXIpO3JldHVybiB0LndyaXRlSWR4PXRoaXMud3JpdGVJZHgsdC5yZWFkSWR4PXRoaXMucmVhZElkeCx0fXdyaXRlKHQscyl7dGhpcy53cml0ZUlkeD0odGhpcy53cml0ZUlkeCsxKSV0aGlzLmJ1ZmZlci5sZW5ndGgsdGhpcy5idWZmZXJbdGhpcy53cml0ZUlkeF09dDtsZXQgZT1NYXRoLm1pbihNYXRoLmZsb29yKHRoaXMuc2FtcGxlUmF0ZSpzKSx0aGlzLmJ1ZmZlci5sZW5ndGgtMSk7dGhpcy5yZWFkSWR4PXRoaXMud3JpdGVJZHgtZSx0aGlzLnJlYWRJZHg8MCYmKHRoaXMucmVhZElkeCs9dGhpcy5idWZmZXIubGVuZ3RoKX1yZWFkKCl7cmV0dXJuIHRoaXMuYnVmZmVyW3RoaXMucmVhZElkeF19fTtjb25zdCB5PTEvNDhlMyxNPTI0LE49TS80O2NsYXNzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7dGhpcy5ub2RlSWQ9dCx0aGlzLnN0YXRlPXMsdGhpcy5zYW1wbGVSYXRlPWUsdGhpcy5zYW1wbGVUaW1lPTEvZSx0aGlzLnNlbmQ9aX19Y2xhc3MgcSBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5lbnY9bmV3IFR9dXBkYXRlKHQscyxlLGksbixyKXtyZXR1cm4gdGhpcy5lbnYuZXZhbCh0LHMsZSxpLG4scil9fWNsYXNzIEYgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MH11cGRhdGUodCl7bGV0IHM9TSp0LzYwLGU9LjU7cmV0dXJuIHRoaXMucGhhc2UrPXRoaXMuc2FtcGxlVGltZSpzLHRoaXMucGhhc2UlMTxlPzE6LTF9fWNsYXNzIEQgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMuaW5TZ249ITAsdGhpcy5vdXRTZ249ITAsdGhpcy5jbG9ja0NudD0wfXVwZGF0ZSh0LHMpe2xldCBlPXQ+MDtyZXR1cm4gdGhpcy5pblNnbiE9ZSYmKHRoaXMuY2xvY2tDbnQrKyx0aGlzLmNsb2NrQ250Pj1zJiYodGhpcy5jbG9ja0NudD0wLHRoaXMub3V0U2duPSF0aGlzLm91dFNnbikpLHRoaXMuaW5TZ249ZSx0aGlzLm91dFNnbj8xOi0xfX1jbGFzcyBMIGV4dGVuZHMgb3tjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLmluU2duPSExfXVwZGF0ZSh0LHMpe2xldCBlPXM+MDtyZXR1cm4gZSYmdGhpcy5pblNnbiE9ZSYmdGhpcy5zZW5kKHt0eXBlOiJDTE9DS19QVUxTRSIsbm9kZUlkOnRoaXMubm9kZUlkLHRpbWU6dH0pLHRoaXMuaW5TZ249ZSwwfX1jb25zdCBPPW5ldyBNYXA7Y2xhc3MgViBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSk7Y29uc3Qgbj1zLmlucHV0c1syXTtuJiZPLmhhcyhuKT90aGlzLmRlbGF5PU8uZ2V0KG4pLmNsb25lKCk6dGhpcy5kZWxheT1uZXcgQShlKSxuJiZPLnNldChuLHRoaXMuZGVsYXkpfXVwZGF0ZSh0LHMpe3JldHVybiB0aGlzLmRlbGF5LndyaXRlKHQscyksdGhpcy5kZWxheS5yZWFkKCl9fWNsYXNzIEcgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpfXVwZGF0ZSh0LHMpe3JldHVybiBrKHQscyl9fWNsYXNzIFIgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMudmFsdWU9MCx0aGlzLnRyaWdTZ249ITF9d3JpdGUodCxzKXshdGhpcy50cmlnU2duJiZzPjAmJih0aGlzLnZhbHVlPXQpLHRoaXMudHJpZ1Nnbj1zPjB9cmVhZCgpe3JldHVybiB0aGlzLnZhbHVlfXVwZGF0ZSh0LHMpe3JldHVybiB0aGlzLndyaXRlKHQscyksdGhpcy5yZWFkKCl9fWNsYXNzIEJ7Y29uc3RydWN0b3IoKXt0aGlzLnZhbHVlPTB9dXBkYXRlKHQpe3JldHVybiB0aGlzLnZhbHVlPXQsdGhpcy52YWx1ZX19Y29uc3QgJD0zNDA7bGV0IEk9MDtjbGFzcyBIe2NvbnN0cnVjdG9yKCl7dGhpcy5jaD1JLHRoaXMuc3RhcnRfc2VlZD0kKih0aGlzLmNoKzEpPj4+MCx0aGlzLnN0YXRlPXRoaXMuc3RhcnRfc2VlZCx0aGlzLnZhbHVlPTAsdGhpcy5hPTE2NjQ1MjUsdGhpcy5jPTEwMTM5MDQyMjMsdGhpcy5tYXNrPTE2Nzc3MjE1LHRoaXMuc2NhbGU9MS8oMTw8MjQpLEkrK311cGRhdGUodCxzKXtpZighdClyZXR1cm4gdGhpcy52YWx1ZTtzJiYodGhpcy5zdGF0ZT10aGlzLnN0YXJ0X3NlZWQpLHRoaXMuc3RhdGU9dGhpcy5zdGF0ZSp0aGlzLmErdGhpcy5jPj4+MDtjb25zdCBlPSh0aGlzLnN0YXRlJnRoaXMubWFzaykqdGhpcy5zY2FsZTtyZXR1cm4gdGhpcy52YWx1ZT1lKjItMSx0aGlzLnZhbHVlfX1jbGFzcyBqe2NvbnN0cnVjdG9yKCl7dGhpcy52YWx1ZT1NYXRoLnJhbmRvbSgpKjItMX11cGRhdGUodCl7cmV0dXJuIHQ/KHRoaXMudmFsdWU9TWF0aC5yYW5kb20oKSoyLTEsdGhpcy52YWx1ZSk6dGhpcy52YWx1ZX19Y2xhc3MgS3t1cGRhdGUodCl7cmV0dXJuIE1hdGgucmFuZG9tKCk8dCp5P01hdGgucmFuZG9tKCk6MH19Y2xhc3MgV3tjb25zdHJ1Y3Rvcigpe3RoaXMub3V0PTB9dXBkYXRlKCl7bGV0IHQ9TWF0aC5yYW5kb20oKSoyLTE7cmV0dXJuIHRoaXMub3V0PSh0aGlzLm91dCsuMDIqdCkvMS4wMix0aGlzLm91dH19Y2xhc3MgWHtjb25zdHJ1Y3Rvcigpe3RoaXMuYjA9MCx0aGlzLmIxPTAsdGhpcy5iMj0wLHRoaXMuYjM9MCx0aGlzLmI0PTAsdGhpcy5iNT0wLHRoaXMuYjY9MH11cGRhdGUoKXtjb25zdCB0PU1hdGgucmFuZG9tKCkqMi0xO3RoaXMuYjA9Ljk5ODg2KnRoaXMuYjArdCouMDU1NTE3OSx0aGlzLmIxPS45OTMzMip0aGlzLmIxK3QqLjA3NTA3NTksdGhpcy5iMj0uOTY5KnRoaXMuYjIrdCouMTUzODUyLHRoaXMuYjM9Ljg2NjUqdGhpcy5iMyt0Ki4zMTA0ODU2LHRoaXMuYjQ9LjU1KnRoaXMuYjQrdCouNTMyOTUyMix0aGlzLmI1PS0uNzYxNip0aGlzLmI1LXQqLjAxNjg5ODtjb25zdCBzPXRoaXMuYjArdGhpcy5iMSt0aGlzLmIyK3RoaXMuYjMrdGhpcy5iNCt0aGlzLmI1K3RoaXMuYjYrdCouNTM2MjtyZXR1cm4gdGhpcy5iNj10Ki4xMTU5MjYscyouMTF9fWNsYXNzIFkgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MX11cGRhdGUodCl7dGhpcy5waGFzZSs9dGhpcy5zYW1wbGVUaW1lKnQ7bGV0IHM9dGhpcy5waGFzZT49MT8xOjA7cmV0dXJuIHRoaXMucGhhc2U9dGhpcy5waGFzZSUxLHN9fWNsYXNzIHogZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MH11cGRhdGUodCxzKXtyZXR1cm4gdGhpcy5waGFzZSs9dGhpcy5zYW1wbGVUaW1lKnQsdGhpcy5waGFzZSUxPHM/MTotMX19Y2xhc3MgWiBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5waGFzZT0wfXVwZGF0ZSh0KXtyZXR1cm4gdGhpcy5waGFzZSs9dGhpcy5zYW1wbGVUaW1lKnQsdGhpcy5waGFzZSUxKjItMX19Y2xhc3MgSntjb25zdHJ1Y3Rvcigpe3RoaXMucGhhc2U9TWF0aC5yYW5kb20oKX11cGRhdGUodCl7Y29uc3Qgcz10L3NhbXBsZVJhdGU7bGV0IGU9RSh0aGlzLnBoYXNlLHMpLGk9Mip0aGlzLnBoYXNlLTEtZTtyZXR1cm4gdGhpcy5waGFzZSs9cyx0aGlzLnBoYXNlPjEmJih0aGlzLnBoYXNlLT0xKSxpfX1jbGFzcyBRIGV4dGVuZHMgb3tjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLnBoYXNlPTAsdGhpcy5zeW5jU2duPSExfXVwZGF0ZSh0LHMsZSl7IXRoaXMuc3luY1NnbiYmcz4wJiYodGhpcy5waGFzZT0wKSx0aGlzLnN5bmNTZ249cz4wO2xldCBpPSh0aGlzLnBoYXNlK2UpJTE7cmV0dXJuIHRoaXMucGhhc2UrPXRoaXMuc2FtcGxlVGltZSp0LE1hdGguc2luKGkqMipNYXRoLlBJKX19Y2xhc3MgdHR7ZEJUb0xpbmVhcih0KXtyZXR1cm4gTWF0aC5wb3coMTAsdC8yMCl9bGluZWFyVG9EQih0KXtyZXR1cm4gMjAqTWF0aC5sb2cxMCh0KX11cGRhdGUodCxzLGUpe2xldCBpPXRoaXMubGluZWFyVG9EQihNYXRoLmFicyh0KSksbj0wO3JldHVybiBpPnMmJihuPShpLXMpKigxLTEvZSkpLHRoaXMuZEJUb0xpbmVhcigtbil9fWNsYXNzIHN0IGV4dGVuZHMgb3tjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLnBoYXNlPTB9dXBkYXRlKHQpe3RoaXMucGhhc2UrPXRoaXMuc2FtcGxlVGltZSp0O2xldCBzPXRoaXMucGhhc2UlMTtyZXR1cm4oczwuNT8yKnM6MS0yKihzLS41KSkqMi0xfX1jbGFzcyBldCBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSk7Y29uc3Qgbj1lLzMwO2coXyhuKSksdGhpcy5idWZmZXI9bmV3IEZsb2F0MzJBcnJheShuKSx0aGlzLndyaXRlUG9zPTB9dXBkYXRlKHQscyxlLGkpe3JldHVybiB0aGlzLmJ1ZmZlclt0aGlzLndyaXRlUG9zXT10LHRoaXMud3JpdGVQb3MrKyx0aGlzLndyaXRlUG9zJXRoaXMuYnVmZmVyLmxlbmd0aD09MCYmKHRoaXMud3JpdGVQb3M9MCx0aGlzLnNlbmQoe3R5cGU6IlNFTkRfU0FNUExFUyIsaWQ6cyxzYW1wbGVzOnRoaXMuYnVmZmVyLGNoYW5uZWxzOmUsY2hhbm5lbDppfSkpLHR9fWNsYXNzIGl0e2NvbnN0cnVjdG9yKCl7dGhpcy5sYWdVbml0PTQ0MTAsdGhpcy5zPTB9dXBkYXRlKHQscyl7cmV0dXJuIHM9cyp0aGlzLmxhZ1VuaXQsczwxJiYocz0xKSx0aGlzLnMrPTEvcyoodC10aGlzLnMpLHRoaXMuc319Y2xhc3MgaHR7Y29uc3RydWN0b3IoKXt0aGlzLmxhc3Q9MH11cGRhdGUodCxzLGUpe2NvbnN0IGk9cyp5LG49ZSp5O2xldCByPXQtdGhpcy5sYXN0O3JldHVybiByPmk/cj1pOnI8LW4mJihyPS1uKSx0aGlzLmxhc3QrPXIsdGhpcy5sYXN0fX1jbGFzcyBhdCBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5zPTB9dXBkYXRlKHQscyl7cmV0dXJuIHM9cyoxZTMsczwxJiYocz0xKSx0aGlzLnMrPTEvcyoodC10aGlzLnMpLHRoaXMuc319Y2xhc3MgbnQgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMuZmlsdGVyPW5ldyB2fXVwZGF0ZSh0LHMsZSl7cmV0dXJuIHRoaXMuZmlsdGVyLmFwcGx5KHQscyxlKSx0aGlzLmZpbHRlci5zMX19Y2xhc3MgcnQgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMuZmlsdGVyPW5ldyB2fXVwZGF0ZSh0LHMsZSl7cmV0dXJuIHRoaXMuZmlsdGVyLmFwcGx5KHQscyxlKSx0aGlzLmZpbHRlci5zMH19Y2xhc3MgdXQgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpfXVwZGF0ZSh0LHMpe3JldHVybiBzPDAmJihzPTApLHM9cysxLHQ9dCpzLDQqKE1hdGguYWJzKC4yNSp0Ky4yNS1NYXRoLnJvdW5kKC4yNSp0Ky4yNSkpLS4yNSl9fWNsYXNzIGx0IGV4dGVuZHMgb3t1cGRhdGUodCl7cmV0dXJuIHR9fWNsYXNzIG0gZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMubm90ZT0wLHRoaXMuZnJlcT0wLHRoaXMudmVsb2NpdHk9MCx0aGlzLmdhdGVTdGF0ZT0ib2ZmIix0aGlzLnR5cGU9Im1pZGlpbiIsdGhpcy5jaGFubmVsPS0xfWlzRnJlZSgpe3JldHVybiB0aGlzLmdhdGVTdGF0ZT09PSJvZmYifW5vdGVPbih0LHMpe3M+MD8odGhpcy5ub3RlPXQsdGhpcy52ZWxvY2l0eT1zLHRoaXMuZnJlcT0yKiooKHQtNjkpLzEyKSo0NDAsdGhpcy5nYXRlU3RhdGU9InByZXRyaWciKTp0aGlzLm5vdGVPZmYoKX1ub3RlT2ZmKCl7dGhpcy5ub3RlPTAsdGhpcy5nYXRlU3RhdGU9Im9mZiJ9Z2V0R2F0ZSgpe3N3aXRjaCh0aGlzLmdhdGVTdGF0ZSl7Y2FzZSJwcmV0cmlnIjpyZXR1cm4gdGhpcy5nYXRlU3RhdGU9Im9uIiwwO2Nhc2Uib24iOnJldHVybiAxO2Nhc2Uib2ZmIjpyZXR1cm4gMDtkZWZhdWx0OmcoITEpfX1nZXRGcmVxKCl7c3dpdGNoKHRoaXMuZ2F0ZVN0YXRlKXtjYXNlInByZXRyaWciOnJldHVybiB0aGlzLmdhdGVTdGF0ZT0ib24iLDA7Y2FzZSJvbiI6cmV0dXJuIHRoaXMuZnJlcTtjYXNlIm9mZiI6cmV0dXJuIHRoaXMuZnJlcTtkZWZhdWx0OmcoITEpfX1nZXRWZWxvY2l0eSgpe3N3aXRjaCh0aGlzLmdhdGVTdGF0ZSl7Y2FzZSJwcmV0cmlnIjpyZXR1cm4gdGhpcy5nYXRlU3RhdGU9Im9uIiwwO2Nhc2Uib24iOnJldHVybiB0aGlzLnZlbG9jaXR5O2Nhc2Uib2ZmIjpyZXR1cm4gdGhpcy52ZWxvY2l0eTtkZWZhdWx0OmcoITEpfX19Y2xhc3Mgb3QgZXh0ZW5kcyBte2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMudHlwZT0ibWlkaWdhdGUifXVwZGF0ZSh0KXtyZXR1cm4gdGhpcy5jaGFubmVsPXQsdGhpcy5nZXRHYXRlKCl9fWNsYXNzIGN0IGV4dGVuZHMgbXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLnR5cGU9Im1pZGlmcmVxIn11cGRhdGUodCl7cmV0dXJuIHRoaXMuY2hhbm5lbD10LHRoaXMuZ2V0RnJlcSgpfX1jbGFzcyBkdCBleHRlbmRzIG17Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy50eXBlPSJtaWRpdmVsIn11cGRhdGUodCl7cmV0dXJuIHRoaXMuY2hhbm5lbD10LHRoaXMuZ2V0VmVsb2NpdHkoKX19Y2xhc3MgZnR7Y29uc3RydWN0b3IodCxzLGUsaSl7dGhpcy51cD0hMSx0aGlzLnNlbmQ9aSx0aGlzLnZhbHVlPTAsdGhpcy50eXBlPSJjYyJ9c2V0VmFsdWUodCl7dGhpcy52YWx1ZT10fXVwZGF0ZSh0LHMsZSl7cmV0dXJuIHRoaXMuaWQ9cywhdGhpcy51cCYmdD4wPyh0aGlzLnVwPSEwLHRoaXMuc2VuZCh7dHlwZToiU0lHTkFMX1RSSUdHRVIiLGlkOnMsdGltZTplfSksdGhpcy52YWx1ZSk6KHRoaXMudXA9dD4wLHRoaXMudmFsdWUpfX1jbGFzcyBwdCBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy50eXBlPSJjYyIsdGhpcy52YWx1ZT1zLmlucHV0c1sxXT8/MH1zZXRWYWx1ZSh0KXt0aGlzLnZhbHVlPXR9dXBkYXRlKHQpe3JldHVybiB0aGlzLmlkPXQsdGhpcy52YWx1ZX19Y2xhc3MgYnQgZXh0ZW5kcyBve2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMudHlwZT0ibWlkaWNjIix0aGlzLnZhbHVlPXMuaW5wdXRzWzJdPz8tMSx0aGlzLmNoYW5uZWw9LTEsdGhpcy5jY251bWJlcj0tMX1zZXRWYWx1ZSh0KXt0aGlzLnZhbHVlPXR9dXBkYXRlKHQscyl7cmV0dXJuIHRoaXMuY2NudW1iZXI9dCx0aGlzLmNoYW5uZWw9cyx0aGlzLnZhbHVlfX1jbGFzcyBndCBleHRlbmRzIG97Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5jbG9ja1Nnbj0hMCx0aGlzLnN0ZXA9MCx0aGlzLmZpcnN0PSEwfXVwZGF0ZSh0LC4uLnMpe3JldHVybiF0aGlzLmNsb2NrU2duJiZ0PjA/KHRoaXMuc3RlcD0odGhpcy5zdGVwKzEpJXMubGVuZ3RoLHRoaXMuY2xvY2tTZ249dD4wLDApOih0aGlzLmNsb2NrU2duPXQ+MCxzW3RoaXMuc3RlcF0pfX1jbGFzcyBtdCBleHRlbmRzIG97dXBkYXRlKHQsLi4ucyl7Y29uc3QgZT10JXMubGVuZ3RoK3MubGVuZ3RoO3JldHVybiBzW01hdGguZmxvb3IoZSklcy5sZW5ndGhdfX1jbGFzcyBTdHt1cGRhdGUodCxzLGUsaSxuKXtsZXQgcj1QKHQscyxlKTtyZXR1cm4gUyhyLGksbil9fWNsYXNzIHd0e3VwZGF0ZSh0LHMsZSl7cmV0dXJuIE1hdGgubWluKE1hdGgubWF4KHQscyksZSl9fWNsYXNzIHZ0e2NvbnN0cnVjdG9yKCl7dGhpcy5oaT0hMX11cGRhdGUodCl7cmV0dXJuIXRoaXMuaGkmJnQ+MD8odGhpcy5oaT0hMCwxKToodGhpcy5oaSYmdDw9MCYmKHRoaXMuaGk9ITEpLDApfX1jbGFzcyB5dHtjb25zdHJ1Y3Rvcigpe3RoaXMueDE9MCx0aGlzLngyPTAsdGhpcy55MT0wLHRoaXMueTI9MCx0aGlzLmEwPTEsdGhpcy5hMT0wLHRoaXMuYTI9MCx0aGlzLmIwPTEsdGhpcy5iMT0wLHRoaXMuYjI9MH11cGRhdGUodD0wLHM9MCxlPTUwMCxpPTEsbj0xKXtjb25zdCByPTIqTWF0aC5QSSplL3NhbXBsZVJhdGUsbD1NYXRoLnNpbihyKTtpPU1hdGgucG93KDEwLGkvMjApO2NvbnN0IHU9bC8oMippKSxjPU1hdGguY29zKHIpO2lmKHM9PT0wKXRoaXMuYjE9MS1jLHRoaXMuYjA9dGhpcy5iMS8yLHRoaXMuYjI9dGhpcy5iMCx0aGlzLmEwPTErdSx0aGlzLmExPS0yKmMsdGhpcy5hMj0xLXU7ZWxzZSBpZihzPT09MSl0aGlzLmIwPSgxK2MpLzIsdGhpcy5iMT0tKDErYyksdGhpcy5iMj10aGlzLmIwLHRoaXMuYTA9MSt1LHRoaXMuYTE9LTIqYyx0aGlzLmEyPTEtdTtlbHNlIGlmKHM9PT0yKXRoaXMuYjA9bC8yLHRoaXMuYjE9MCx0aGlzLmIyPS10aGlzLmIwLHRoaXMuYTA9MSt1LHRoaXMuYTE9LTIqYyx0aGlzLmEyPTEtdTtlbHNlIGlmKHM9PT0zKXRoaXMuYjA9MSx0aGlzLmIxPS0yKmMsdGhpcy5iMj0xLHRoaXMuYTA9MSt1LHRoaXMuYTE9LTIqYyx0aGlzLmEyPTEtdTtlbHNlIGlmKHM9PT00KXRoaXMuYjA9MS11LHRoaXMuYjE9LTIqYyx0aGlzLmIyPTErdSx0aGlzLmEwPTErdSx0aGlzLmExPS0yKmMsdGhpcy5hMj0xLXU7ZWxzZSBpZihzPT09NSl7Y29uc3QgYT1NYXRoLnBvdygxMCxuLzQwKTt0aGlzLmIwPTErdSphLHRoaXMuYjE9LTIqYyx0aGlzLmIyPTEtdSphLHRoaXMuYTA9MSt1L2EsdGhpcy5hMT0tMipjLHRoaXMuYTI9MS11L2F9ZWxzZSBpZihzPT09Nil7Y29uc3QgYT1NYXRoLnBvdygxMCxuLzQwKSxkPTIqTWF0aC5zcXJ0KGEpKnUsZj0oYS0xKSpjLHA9KGErMSkqYzt0aGlzLmIwPWEqKGErMS1mK2QpLHRoaXMuYjE9MiphKihhLTEtcCksdGhpcy5iMj1hKihhKzEtZi1kKSx0aGlzLmEwPWErMStmK2QsdGhpcy5hMT0tMiooYS0xK3ApLHRoaXMuYTI9YSsxK2YtZH1lbHNlIGlmKHM9PT03KXtjb25zdCBhPU1hdGgucG93KDEwLG4vNDApLGQ9MipNYXRoLnNxcnQoYSkqdSxmPShhLTEpKmMscD0oYSsxKSpjO3RoaXMuYjA9YSooYSsxK2YrZCksdGhpcy5iMT0tMiphKihhLTErcCksdGhpcy5iMj1hKihhKzErZi1kKSx0aGlzLmEwPWErMS1mK2QsdGhpcy5hMT0yKihhLTEtcCksdGhpcy5hMj1hKzEtZi1kfXRoaXMuYjAvPXRoaXMuYTAsdGhpcy5iMS89dGhpcy5hMCx0aGlzLmIyLz10aGlzLmEwLHRoaXMuYTEvPXRoaXMuYTAsdGhpcy5hMi89dGhpcy5hMCx0aGlzLmEwPTE7Y29uc3QgYj10aGlzLmIwKnQrdGhpcy5iMSp0aGlzLngxK3RoaXMuYjIqdGhpcy54Mi10aGlzLmExKnRoaXMueTEtdGhpcy5hMip0aGlzLnkyO3JldHVybiB0aGlzLngyPXRoaXMueDEsdGhpcy54MT10LHRoaXMueTI9dGhpcy55MSx0aGlzLnkxPWIsYn19Y29uc3QgTXQ9T2JqZWN0LmZyZWV6ZShPYmplY3QuZGVmaW5lUHJvcGVydHkoe19fcHJvdG9fXzpudWxsLEFEU1JOb2RlOnEsQXVkaW9JbjpsdCxBdWRpb05vZGU6byxCUEY6cnQsQmlxdWFkRmlsdGVyOnl0LEJyb3duTm9pc2VPc2M6VyxDQzpwdCxDTE9DS19QUFE6TSxDTE9DS19QUFM6TixDbGlwOnd0LENsb2NrOkYsQ2xvY2tEaXY6RCxDbG9ja091dDpMLERlbGF5OlYsRGlzdG9ydDpHLER1c3RPc2M6SyxGaWx0ZXI6bnQsRm9sZDp1dCxIb2xkOlIsSW1wdWxzZU9zYzpZLExhZzppdCxMY2dOb2lzZTpILE1pZGlDQzpidCxNaWRpRnJlcTpjdCxNaWRpR2F0ZTpvdCxNaWRpSW46bSxNaWRpVmVsOmR0LE5vaXNlT3NjOmosT3V0cHV0OkIsUGljazptdCxQaW5rTm9pc2U6WCxQdWxzZU9zYzp6LFJlbWFwOlN0LFNhd09zYzpKLFNjb3BlOmV0LFNlcXVlbmNlOmd0LFNpZGVjaGFpbkNvbXByZXNzb3I6dHQsU2lnbmFsOmZ0LFNpbmVPc2M6USxTbGV3Omh0LFNsaWRlOmF0LFRyaU9zYzpzdCxUcmlnOnZ0LFphd09zYzpafSxTeW1ib2wudG9TdHJpbmdUYWcse3ZhbHVlOiJNb2R1bGUifSkpLHg9bmV3IE1hcChPYmplY3QuZW50cmllcyhNdCkpO2NsYXNzIE90e2NvbnN0cnVjdG9yKHQscyl7Zyh0PT00OGUzKSx0aGlzLnNhbXBsZVJhdGU9dCx0aGlzLnBsYXlQb3M9MCx0aGlzLnNlbmQ9cyx0aGlzLnVuaXRzPVtdLHRoaXMudW5pdElEPTAsdGhpcy5mYWRlVGltZT0uMDEsdGhpcy5tYXhVbml0cz0xLHRoaXMucT1bXX1mYWRlT3V0VW5pdCh0KXt0LmZhZGVPdXQodGhpcy5wbGF5UG9zLHRoaXMuZmFkZVRpbWUpLHRoaXMuZnJlZVVuaXQodC5pZCx0aGlzLmZhZGVUaW1lKX1mYWRlT3V0VW5pdEJ5SWQodCl7Y29uc3Qgcz10aGlzLnVuaXRzLmZpbmQoZT0+ZS5pZD09PXQpO3MmJnRoaXMuZmFkZU91dFVuaXQocyl9ZmFkZU91dEFsbFVuaXRzKCl7dGhpcy51bml0cy5mb3JFYWNoKHQ9PnRoaXMuZmFkZU91dFVuaXQodCkpfWZhZGVPdXRPbGRVbml0cygpe2NvbnN0IHQ9dGhpcy51bml0cy5maWx0ZXIoZT0+ZS5hY3RpdmUpLHM9dC5sZW5ndGgtdGhpcy5tYXhVbml0cztzPD0wfHx0LnNsaWNlKDAscykuZm9yRWFjaChlPT50aGlzLmZhZGVPdXRVbml0KGUpKX1zdG9wKCl7dGhpcy5mYWRlT3V0QWxsVW5pdHMoKSx0aGlzLnNlbmQoe3R5cGU6IlNUT1AiLGZhZGVUaW1lOnRoaXMuZmFkZVRpbWV9KX1zcGF3blVuaXQodCxzKXtjb25zdCBlPW5ldyB4dCh0aGlzLnVuaXRJRCsrLHQsdGhpcy5zYW1wbGVSYXRlLHRoaXMuc2VuZCk7dGhpcy51bml0cy5wdXNoKGUpLGUuZmFkZUluKHRoaXMucGxheVBvcyx0aGlzLmZhZGVUaW1lKSx0aGlzLmZhZGVPdXRPbGRVbml0cygpLGNvbnNvbGUubG9nKGBzcGF3biB1bml0ICR7ZS5pZH0sIHVuaXRzIGFsaXZlOiAke3RoaXMudW5pdHMubGVuZ3RofWApLHMmJnRoaXMuc2NoZWR1bGVNZXNzYWdlKHttc2c6e3R5cGU6IkZBREVfT1VUX1VOSVQiLGlkOmUuaWR9LHRpbWU6c30pfWZyZWVVbml0KHQscyl7aWYocyl7dGhpcy5zY2hlZHVsZU1lc3NhZ2Uoe21zZzp7dHlwZToiRlJFRV9VTklUIixpZDp0fSx0aW1lOnN9KTtyZXR1cm59Y29uc3QgZT10aGlzLnVuaXRzLmxlbmd0aDt0aGlzLnVuaXRzPXRoaXMudW5pdHMuZmlsdGVyKGk9PmkuaWQhPT10KSxlPnRoaXMudW5pdHMubGVuZ3RoJiZjb25zb2xlLmxvZyhgZnJlZSB1bml0ICR7dH0sIHVuaXRzIGFsaXZlOiAke3RoaXMudW5pdHMubGVuZ3RofWApfXBhcnNlTXNnKHQpe3N3aXRjaCh0LnR5cGUpe2Nhc2UiU1BBV05fVU5JVCI6dGhpcy5zcGF3blVuaXQodC51bml0LHQuZHVyYXRpb24pO2JyZWFrO2Nhc2UiRlJFRV9VTklUIjp0aGlzLmZyZWVVbml0KHQuaWQpO2JyZWFrO2Nhc2UiRkFERV9PVVRfVU5JVCI6dGhpcy5mYWRlT3V0VW5pdEJ5SWQodC5pZCk7YnJlYWs7Y2FzZSJOT1RFX09OIjp0aGlzLm5vdGVPbih0KTticmVhaztjYXNlIkNDIjp0aGlzLm1pZGlDQyh0KTticmVhaztjYXNlIlNFVF9DT05UUk9MIjp0aGlzLnNldENvbnRyb2wodCk7YnJlYWs7Y2FzZSJGQURFX1RJTUUiOnRoaXMuZmFkZVRpbWU9TnVtYmVyKHQuZmFkZVRpbWUpO2JyZWFrO2Nhc2UiTUFYX1VOSVRTIjp0aGlzLm1heFVuaXRzPU51bWJlcih0Lm1heFVuaXRzKTticmVhaztjYXNlIlNUT1AiOnRoaXMuc3RvcCgpO2JyZWFrO2Nhc2UiU0VUX1VHRU4iOnRoaXMuYWRkVWdlbih0LmNsYXNzTmFtZSx0LnVnZW4pO2JyZWFrO2Nhc2UiU0NIRURVTEVfTVNHIjp0aGlzLnNjaGVkdWxlTWVzc2FnZSh0KTticmVhaztjYXNlIkJBVENIX01TRyI6dC5tZXNzYWdlcy5mb3JFYWNoKHM9PnRoaXMucGFyc2VNc2cocykpO2JyZWFrO2RlZmF1bHQ6dGhyb3cgbmV3IFR5cGVFcnJvcihgdW5rbm93biBtZXNzYWdlIHR5cGUgJHt0LnR5cGV9YCl9fW5vdGVPbih0KXt0aGlzLnVuaXRzLmZvckVhY2gocz0+cy5ub3RlT24odCkpfW1pZGlDQyh0KXt0aGlzLnVuaXRzLmZvckVhY2gocz0+cy5taWRpQ0ModCkpfXNldENvbnRyb2wodCl7dGhpcy51bml0cy5mb3JFYWNoKHM9PnMuc2V0Q29udHJvbCh0KSl9c2NoZWR1bGVNZXNzYWdlKHQpe2lmKHQudGltZT10aGlzLnBsYXlQb3MrdC50aW1lLCF0aGlzLnEubGVuZ3RoKXt0aGlzLnEucHVzaCh0KTtyZXR1cm59bGV0IHM9MDtmb3IoO3M8dGhpcy5xLmxlbmd0aCYmdGhpcy5xW3NdLnRpbWU8dC50aW1lOylzKys7dGhpcy5xLnNwbGljZShzLDAsdCl9Z2VuU2FtcGxlKHQpe2Zvcig7dGhpcy5xLmxlbmd0aD4wJiZ0aGlzLnFbMF0udGltZTw9dGhpcy5wbGF5UG9zOyl0aGlzLnBhcnNlTXNnKHRoaXMucVswXS5tc2cpLHRoaXMucS5zaGlmdCgpO2lmKCF0aGlzLnVuaXRzLmxlbmd0aClyZXR1cm5bMCwwXTtjb25zdCBzPVswLDBdO2ZvcihsZXQgZT0wO2U8dGhpcy51bml0cy5sZW5ndGg7ZSsrKXtjb25zdCBpPXRoaXMudW5pdHNbZV0sbj1pLmdldExldmVsKHRoaXMucGxheVBvcyk7aS5nZW5TYW1wbGUodGhpcy5wbGF5UG9zLGkubm9kZXMsdCxpLnJlZ2lzdGVycyxpLm91dHB1dHMsaS5zb3VyY2VzKSxzWzBdKz1pLm91dHB1dHNbMF0qbixzWzFdKz1pLm91dHB1dHNbMV0qbn1yZXR1cm4gdGhpcy5wbGF5UG9zKz0xLzQ4ZTMsc31hZGRVZ2VuKHQscyl7Y29uc3QgZT1uZXcgRnVuY3Rpb24oYCR7c307cmV0dXJuICR7dH1gKSgpO3guc2V0KHQsZSl9fWNsYXNzIHh0e2NvbnN0cnVjdG9yKHQscyxlLGkpe3RoaXMuaWQ9dCx0aGlzLnNhbXBsZVJhdGU9ZSx0aGlzLnNlbmQ9aSx0aGlzLm5vZGVzPVtdLHRoaXMuYWN0aXZlPSEwO2ZvcihsZXQgciBpbiBzLnVnZW5zKXtjb25zdCBsPXMudWdlbnNbcl07aWYoeC5oYXMobC50eXBlKSl7Y29uc3QgdT14LmdldChsLnR5cGUpLGM9TnVtYmVyKHIpO3RoaXMubm9kZXNbY109bmV3IHUoYyxsLHRoaXMuc2FtcGxlUmF0ZSx0aGlzLnNlbmQpfWVsc2UgY29uc29sZS53YXJuKGB1bmtub3duIHVnZW4gIiR7bC50eXBlfSJgKX10aGlzLnJlZ2lzdGVycz1uZXcgQXJyYXkocy5yZWdpc3RlcnMpLmZpbGwoMCk7bGV0IG49MTY7dGhpcy5vdXRwdXRzPW5ldyBBcnJheShuKS5maWxsKDApLHRoaXMuc291cmNlcz1uZXcgQXJyYXkobikuZmlsbCgwKSxzLnNyYz1gby5maWxsKDApOyAvLyByZXNldCBvdXRwdXRzCmArcy5zcmMsdGhpcy5nZW5TYW1wbGU9bmV3IEZ1bmN0aW9uKCJ0aW1lIiwibm9kZXMiLCJpbnB1dCIsInIiLCJvIiwicyIscy5zcmMpfW5vdGVPbih0KXt2YXIgdSxjLGI7Y29uc3R7Y2hhbm5lbDpzLG5vdGU6ZSx2ZWxvY2l0eTppfT10LG49dGhpcy5ub2Rlcy5maWx0ZXIoYT0+YS50eXBlPT09Im1pZGlmcmVxIiYmKGEuY2hhbm5lbD09PS0xfHxhLmNoYW5uZWw9PT1zKSkscj10aGlzLm5vZGVzLmZpbHRlcihhPT5hLnR5cGU9PT0ibWlkaWdhdGUiJiYoYS5jaGFubmVsPT09LTF8fGEuY2hhbm5lbD09PXMpKSxsPXRoaXMubm9kZXMuZmlsdGVyKGE9PmEudHlwZT09PSJtaWRpdmVsIiYmKGEuY2hhbm5lbD09PS0xfHxhLmNoYW5uZWw9PT1zKSk7aWYoaT4wKXtsZXQgYT1uLmZpbmQocD0+cC5pc0ZyZWUoKSl8fG5bMF0sZD1yLmZpbmQocD0+cC5pc0ZyZWUoKSl8fHJbMF0sZj1sLmZpbmQocD0+cC5pc0ZyZWUoKSl8fGxbMF07YT09bnVsbHx8YS5ub3RlT24oZSxpKSxkPT1udWxsfHxkLm5vdGVPbihlLGkpLGY9PW51bGx8fGYubm90ZU9uKGUsaSl9ZWxzZSh1PW4uZmluZChhPT5hLm5vdGU9PT1lKSk9PW51bGx8fHUubm90ZU9mZigpLChjPXIuZmluZChhPT5hLm5vdGU9PT1lKSk9PW51bGx8fGMubm90ZU9mZigpLChiPWwuZmluZChhPT5hLm5vdGU9PT1lKSk9PW51bGx8fGIubm90ZU9mZigpfW1pZGlDQyh0KXtjb25zdHtjaGFubmVsOnMsY2M6ZSx2YWx1ZTppfT10O3RoaXMubm9kZXMuZm9yRWFjaChuPT57bi50eXBlPT09Im1pZGljYyImJihuLmNoYW5uZWw9PT0tMXx8bi5jaGFubmVsPT09cykmJm4uY2NudW1iZXI9PT1lJiZuLnNldFZhbHVlKGkpfSl9c2V0Q29udHJvbCh0KXtjb25zdHt2YWx1ZTpzLGlkOmV9PXQsaT10aGlzLm5vZGVzLmZpbmQobj0+bi50eXBlPT09ImNjIiYmbi5pZD09PWUpO2kmJmkuc2V0VmFsdWUocyl9Z2V0TGV2ZWwodCl7cmV0dXJuIHRoaXMuZmFkZVN0YXJ0PT09dm9pZCAwPzA6dGhpcy5hY3RpdmU/UygodC10aGlzLmZhZGVTdGFydCkvdGhpcy5mYWRlVGltZSwwLC4zKTpTKCh0LXRoaXMuZmFkZVN0YXJ0KS90aGlzLmZhZGVUaW1lLHRoaXMuZmFkZUZyb20sMCl9ZmFkZUluKHQscyl7dGhpcy5mYWRlU3RhcnQ9dCx0aGlzLmZhZGVUaW1lPXN9ZmFkZU91dCh0LHMpe3RoaXMuZmFkZVRpbWU9cyx0aGlzLmZhZGVGcm9tPXRoaXMuZ2V0TGV2ZWwodCksdGhpcy5hY3RpdmU9ITEsdGhpcy5mYWRlU3RhcnQ9dH1pc0RvbmUodCl7cmV0dXJuIXRoaXMuYWN0aXZlJiZ0aGlzLmdldExldmVsKHQpPT09MH19Y2xhc3MgVHQgZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMucG9ydC5vbm1lc3NhZ2U9dGhpcy5vbm1lc3NhZ2UuYmluZCh0aGlzKSx0aGlzLmF1ZGlvR3JhcGg9bmV3IE90KDQ4ZTMsdGhpcy5wb3J0LnBvc3RNZXNzYWdlLmJpbmQodGhpcy5wb3J0KSl9b25tZXNzYWdlKHQpe2xldCBzPXQuZGF0YTt0aGlzLmF1ZGlvR3JhcGgucGFyc2VNc2cocyl9cHJvY2Vzcyh0LHMsZSl7Y29uc3QgaT1zWzBdLG49dFswXVswXSxyPWlbMF0sbD1pWzFdO2ZvcihsZXQgdT0wO3U8ci5sZW5ndGg7dSsrKXtsZXRbYyxiXT10aGlzLmF1ZGlvR3JhcGguZ2VuU2FtcGxlKG4/blt1XTowKTtyW3VdPWMsbFt1XT1ifXJldHVybiEwfX1yZWdpc3RlclByb2Nlc3Nvcigic2FtcGxlLWdlbmVyYXRvciIsVHQpfSkoKTsK";
  var ye = "data:text/javascript;base64,KGZ1bmN0aW9uKCl7InVzZSBzdHJpY3QiO2NsYXNzIG4gZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7c3RhdGljIGdldCBwYXJhbWV0ZXJEZXNjcmlwdG9ycygpe3JldHVyblt7bmFtZToiaXNSZWNvcmRpbmciLGRlZmF1bHRWYWx1ZTowfV19Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMuX2J1ZmZlclNpemU9MjA0OCx0aGlzLl9idWZmZXI9bmV3IEZsb2F0MzJBcnJheSh0aGlzLl9idWZmZXJTaXplKSx0aGlzLl9pbml0QnVmZmVyKCl9X2luaXRCdWZmZXIoKXt0aGlzLl9ieXRlc1dyaXR0ZW49MH1faXNCdWZmZXJFbXB0eSgpe3JldHVybiB0aGlzLl9ieXRlc1dyaXR0ZW49PT0wfV9pc0J1ZmZlckZ1bGwoKXtyZXR1cm4gdGhpcy5fYnl0ZXNXcml0dGVuPT09dGhpcy5fYnVmZmVyU2l6ZX1fYXBwZW5kVG9CdWZmZXIoZSl7dGhpcy5faXNCdWZmZXJGdWxsKCkmJnRoaXMuX2ZsdXNoKCksdGhpcy5fYnVmZmVyW3RoaXMuX2J5dGVzV3JpdHRlbl09ZSx0aGlzLl9ieXRlc1dyaXR0ZW4rPTF9X2ZsdXNoKCl7bGV0IGU9dGhpcy5fYnVmZmVyO3RoaXMuX2J5dGVzV3JpdHRlbjx0aGlzLl9idWZmZXJTaXplJiYoZT1lLnNsaWNlKDAsdGhpcy5fYnl0ZXNXcml0dGVuKSksdGhpcy5wb3J0LnBvc3RNZXNzYWdlKHtldmVudFR5cGU6ImRhdGEiLGF1ZGlvQnVmZmVyOmV9KSx0aGlzLl9pbml0QnVmZmVyKCl9X3JlY29yZGluZ1N0b3BwZWQoKXt0aGlzLnBvcnQucG9zdE1lc3NhZ2Uoe2V2ZW50VHlwZToic3RvcCJ9KX1wcm9jZXNzKGUsbyxoKXtjb25zdCBpPWguaXNSZWNvcmRpbmcsZj1vWzBdLHM9ZVswXSx1PWZbMF0sXz1mWzFdO2xldCByPSExO2ZvcihsZXQgdD0wO3Q8dS5sZW5ndGg7dCsrKXQ8aS5sZW5ndGgmJihyPWlbdF09PT0xKSwhciYmIXRoaXMuX2lzQnVmZmVyRW1wdHkoKSYmKHRoaXMuX2ZsdXNoKCksdGhpcy5fcmVjb3JkaW5nU3RvcHBlZCgpKSxyJiYodGhpcy5fYXBwZW5kVG9CdWZmZXIoc1swXVt0XSksdGhpcy5fYXBwZW5kVG9CdWZmZXIoc1sxXVt0XSkpLHVbdF09c1swXVt0XSxfW3RdPXNbMV1bdF07cmV0dXJuITB9fXJlZ2lzdGVyUHJvY2Vzc29yKCJyZWNvcmRlciIsbil9KSgpOwo=";
  function fe(e, t, i) {
    if (e.length < 1)
      return;
    e[0];
    const n2 = 3, l2 = 32, o = e.map((X) => X.length).reduce((X, z4) => X + z4, 0), d2 = l2 / 8, G4 = i * d2, p2 = 44, m3 = new ArrayBuffer(p2 + o * d2), r = new DataView(m3);
    V(r, 0, "RIFF"), r.setUint32(4, 36 + o * d2, true), V(r, 8, "WAVE"), V(r, 12, "fmt "), r.setUint32(16, 16, true), r.setUint16(20, n2, true), r.setUint16(22, i, true), r.setUint32(24, t, true), r.setUint32(28, t * G4, true), r.setUint16(32, G4, true), r.setUint16(34, l2, true), V(r, 36, "data"), r.setUint32(40, o * d2, true);
    let R5 = 44;
    for (const X of e)
      ge(r, R5, X), R5 += X.length * d2;
    return m3;
  }
  function V(e, t, i) {
    for (let n2 = 0; n2 < i.length; n2++)
      e.setUint8(t + n2, i.charCodeAt(n2));
  }
  function ge(e, t, i) {
    for (var n2 = 0; n2 < i.length; n2++, t += 4)
      e.setFloat32(t, i[n2], true);
  }
  var k = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
    __proto__: null,
    Node: c,
    compile: T,
    evaluate: j,
    exit: J,
    exportModule: ce,
    getInletName: oe,
    getNode: F,
    module: g,
    n: f,
    node: x,
    nodeRegistry: y,
    outputType: Y,
    polyType: Z,
    register: u,
    registerNode: a
  }, Symbol.toStringTag, { value: "Module" }));
  var Xe = (e) => `Math.sin(${e})`;
  var Ze = (e) => `Math.cos(${e})`;
  var be = (e) => `Math.tan(${e})`;
  var xe = (e) => `Math.asin(${e})`;
  var Re = (e) => `Math.acos(${e})`;
  var Le = (e) => `Math.atan(${e})`;
  var B = (e, t, i) => `${e} = ${t};${i ? ` /* ${i} */` : ""}`;
  var w = (e, ...t) => B(
    e.name,
    `nodes[${e.ugenIndex}].update(${t.join(",")})`,
    e.node.type
  );
  var Me = (e) => `(2 ** ((${e} - 69) / 12) * 440)`;
  var ze = (e, t) => `${e} ** ${t}`;
  var Ve = (e) => `Math.exp(${e})`;
  var We = (e) => `Math.log(${e})`;
  var Ye = (e, t) => `${e}%${t}`;
  var Ne = (e) => `Math.abs(${e})`;
  var He = (e) => `Math.round(${e})`;
  var Se = (e) => `Math.floor(${e})`;
  var Te = (e) => `Math.sign(${e})`;
  var we = (e) => `Math.ceil(${e})`;
  var Ke = (e, t) => `Math.min(${e}, ${t})`;
  var Ce = (e, t) => `Math.max(${e}, ${t})`;
  var ve = (e, t) => `[${e}, ${t}]`;
  var L = (e) => `${e}[0]`;
  var Ie = (e) => `${e}[1]`;
  var Ue = (e, t) => `(${L(e)} < ${L(t)} ? ${e} : ${t})`;
  var ke = (e, t) => `(${L(e)} > ${L(t)} ? ${e} : ${t})`;
  var Pe = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
    __proto__: null,
    abs: Ne,
    ceil: we,
    def: B,
    defAcos: Re,
    defAsin: xe,
    defAtan: Le,
    defCos: Ze,
    defSin: Xe,
    defTan: be,
    defUgen: w,
    exp: Ve,
    floor: Se,
    log: We,
    max: Ce,
    midinote: Me,
    min: Ke,
    mod: Ye,
    pair_a: L,
    pair_a_max: ke,
    pair_a_min: Ue,
    pair_b: Ie,
    pair_make: ve,
    pow: ze,
    round: He,
    sign: Te
  }, Symbol.toStringTag, { value: "Module" }));
  var Fe = class {
    constructor(t = null) {
      this.ugens = /* @__PURE__ */ new Map(), this.outputNode = t;
    }
    async spawn(t, i) {
      this.graph = t;
      const { src: n2, ugens: l2, registers: o } = t.compile({
        log: false
      });
      !this.mouse && n2.includes("mouse") && this.initMouse(), !this.midiInited && l2.some((d2) => d2.type.startsWith("Midi")) && this.initMidi(), !this.audioIn && l2.some((d2) => d2.type === "AudioIn") && await this.initAudioIn(), this.sendCustomUgens(), this.send({
        type: "SPAWN_UNIT",
        unit: { src: n2, ugens: l2, registers: o },
        duration: i
        // experimental
      });
    }
    // ugen is expected to be a class
    registerUgen(t) {
      this.ugens.set(t.name, t);
    }
    // custom ugens
    sendCustomUgens() {
      if (!this.ugens.size)
        return;
      let t = [];
      for (let [i, n2] of this.ugens)
        t.push({
          type: "SET_UGEN",
          className: i,
          ugen: n2 + ""
        });
      this.send({
        type: "BATCH_MSG",
        messages: t
      });
    }
    scheduleMessage(t, i) {
      this.send({
        type: "SCHEDULE_MSG",
        msg: t,
        time: i
      });
    }
    setControl(t, i, n2) {
      const l2 = {
        type: "SET_CONTROL",
        id: t,
        value: i
      };
      n2 ? this.send({ type: "SCHEDULE_MSG", time: n2, msg: l2 }) : this.send(l2);
    }
    // controls: { id, value, time }[]
    setControls(t) {
      const i = {
        type: "BATCH_MSG",
        messages: t.map((n2) => {
          const l2 = { type: "SET_CONTROL", id: n2.id, value: n2.value };
          return n2.time === void 0 ? l2 : {
            type: "SCHEDULE_MSG",
            time: n2.time,
            msg: l2
          };
        })
      };
      this.send(i);
    }
    async initAudioIn() {
      console.log("init audio input...");
      const t = await navigator.mediaDevices.getUserMedia({
        audio: {
          echoCancellation: false,
          noiseSuppression: false,
          autoGainControl: false
        }
      });
      this.audioCtx.createMediaStreamSource(t).connect(this.audioWorklet);
    }
    initMidi() {
      console.log("init midi input..."), this.midiInited = true, new me().on("midimessage", (i, n2) => {
        const l2 = re(n2);
        l2 && this.send(l2);
      });
    }
    initMouse() {
      console.log("init mouse"), this.mouse = new he(), this.mouse.on("move", (t, i) => {
        this.setControl("mouseX", t), this.setControl("mouseY", i);
      });
    }
    /**
     * Send a message to the audio thread (audio worket)
     */
    send(t) {
      W(t instanceof Object), this.audioWorklet && this.audioWorklet.port.postMessage(t);
    }
    async init() {
      if (!this.audioCtx) {
        if (W(!this.audioCtx), this.audioCtx = this.outputNode?.context || new AudioContext({
          latencyHint: "interactive",
          sampleRate: 48e3
        }), await this.audioCtx.resume(), !this.audioCtx.audioWorklet)
          throw new Error(
            "Audio cannot be loaded: non-secure origin? (AudioContext.audioWorklet is undefined)"
          );
        await this.audioCtx.audioWorklet.addModule(Ge), await this.audioCtx.audioWorklet.addModule(ye), this.audioWorklet = new AudioWorkletNode(
          this.audioCtx,
          "sample-generator",
          {
            outputChannelCount: [2]
          }
        ), this.audioWorklet.port.onmessage = (t) => {
          const { id: i, time: n2, type: l2 } = t.data;
          l2 === "SIGNAL_TRIGGER" ? this.graph.dfs((o) => {
            if (o.type === "signal" && o.id === i) {
              const d2 = o.callback(n2, i);
              isNaN(d2) ? d2 !== void 0 && console.warn(
                `expected number from "on" callback with id "${i}", got "${d2}" instead.`
              ) : window.postMessage({
                type: "KABELSALAT_SET_CONTROL",
                value: d2,
                id: i
              });
            }
            return o;
          }) : l2 === "STOP" ? setTimeout(() => this.destroy(), t.data.fadeTime * 1e3 + 200) : l2 === "SEND_SAMPLES" && this.graph.dfs((o) => (o.type !== "scope" || o.ins.length < 2 || o.ins[1].value !== i || window.postMessage({
            type: "KABELSALAT_UPDATE_SCOPE",
            samples: t.data.samples,
            channels: t.data.channels,
            channel: t.data.channel,
            id: i
          }), o));
        }, this.recorder = new window.AudioWorkletNode(this.audioCtx, "recorder"), this.audioWorklet.connect(this.recorder), this.sendCustomUgens(), this.recorder.connect(this.outputNode || this.audioCtx.destination), this.recorder.port.onmessage = (t) => {
          if (t.data.eventType === "data" && this.recordedBuffers.push(t.data.audioBuffer), t.data.eventType === "stop") {
            console.log("recording stopped");
            const i = fe(
              this.recordedBuffers,
              this.audioCtx.sampleRate,
              2
            );
            Je(i, "kabelsalat.wav", "audio/wav"), this.recordedBuffers = [];
          }
        }, this.recordOnPlay && this.record();
      }
    }
    destroy() {
      this.audioWorklet?.disconnect(), this.audioWorklet = null, this.recorder?.disconnect(), this.recorder = null, !this.outputNode && this.audioCtx?.close(), this.audioCtx = null;
    }
    /**
     * Stop audio playback
     */
    stop() {
      this.audioCtx && this.send({ type: "STOP" }), this.mouse?.detach();
    }
    record() {
      if (!this.audioCtx) {
        this.recordOnPlay = true;
        return;
      }
      this.recordedBuffers = [], this.recorder.parameters.get("isRecording").setValueAtTime(1, 0), console.log("recording started");
    }
    stopRecording() {
      this.recordOnPlay = false, this.audioCtx && this.recorder.parameters.get("isRecording").setValueAtTime(0, 0);
    }
    set fadeTime(t) {
      this.send({ type: "FADE_TIME", fadeTime: t });
    }
    set maxUnits(t) {
      this.send({ type: "MAX_UNITS", maxUnits: t });
    }
  };
  function Je(e, t, i) {
    const n2 = new Blob([e], { type: i }), l2 = document.createElement("a");
    l2.href = window.URL.createObjectURL(n2), l2.download = t, l2.click();
  }
  var je = 0;
  var _i = u(
    "signal",
    (e, t) => {
      const i = je++, n2 = getNode("signal", e, i);
      return n2.callback = t, n2.id = i, n2;
    },
    {
      ugen: "Signal",
      compile: ({ vars: [e, t], ...i }) => w(i, e, t, "time")
    }
  );
  var Qe = (e) => `sin(${e})`;
  var Be = (e) => `cos(${e})`;
  var Ee = (e) => `tan(${e})`;
  var Oe = (e) => `asin(${e})`;
  var $e = (e) => `acos(${e})`;
  var De = (e) => `atan(${e})`;
  var N = (e, t, i) => `${e} = ${t};${i ? ` /* ${i} */` : ""}`;
  var Ae = (e, ...t) => {
    if (t.unshift(`nodes[${e.ugenIndex}]`), e.ugen === "Sequence" || e.ugen === "Pick") {
      const i = t.length - 2, n2 = `(float[${i}]){${t.slice(2).join(",")}}`;
      return N(
        e.name,
        `${e.ugen}_update(${t[0]}, ${t[1]}, ${i}, ${n2})`,
        e.ugen
      );
    }
    return N(e.name, `${e.ugen}_update(${t.join(",")})`, e.ugen);
  };
  var qe = (e) => `pow(2.0, ((${e} - 69.0) / 12.0)) * 440.0`;
  var _e = (e, t) => `pow(${e}, ${t})`;
  var et = (e) => `exp(${e})`;
  var tt = (e) => `log(${e})`;
  var it = (e, t) => `${e}>=${t}?${e}-${t}:${e}`;
  var nt = (e) => `fabs(${e})`;
  var st = (e, t) => `fmin(${e}, ${t})`;
  var lt = (e, t) => `fmax(${e}, ${t})`;
  var at = (e) => `fround(${e})`;
  var ot = (e) => `floor(${e})`;
  var dt = (e) => `ceil(${e})`;
  var ct = (e, t) => `((pair) {${e}, ${t}})`;
  var M = (e) => `${e}.a`;
  var pt = (e) => `${e}.b`;
  var ut = (e, t) => `(${M(e)} < ${M(t)} ? ${e} : ${t})`;
  var mt = (e, t) => `(${M(e)} > ${M(t)} ? ${e} : ${t})`;
  var rt = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
    __proto__: null,
    abs: nt,
    ceil: dt,
    def: N,
    defAcos: $e,
    defAsin: Oe,
    defAtan: De,
    defCos: Be,
    defSin: Qe,
    defTan: Ee,
    defUgen: Ae,
    exp: et,
    floor: ot,
    log: tt,
    max: lt,
    midinote: qe,
    min: st,
    mod: it,
    pair_a: M,
    pair_a_max: mt,
    pair_a_min: ut,
    pair_b: pt,
    pair_make: ct,
    pow: _e,
    round: at
  }, Symbol.toStringTag, { value: "Module" }));
  var s = {
    js: Pe,
    c: rt
  };
  var E = (e, t) => a(e, {
    ugen: t,
    compile: ({ vars: i, ...n2 }) => s[n2.lang].defUgen(n2, ...i)
  });
  var ht = u("time", (e) => new c("time", e), {
    tags: ["meta"],
    description: "Returns elapsed time in seconds",
    compile: ({ name: e, lang: t }) => s[t].def(e, "time")
  });
  var Gt = u(
    "raw",
    (e, t) => new c("raw", t).withIns(f(e)),
    {
      ins: [
        { name: "in" },
        {
          name: "code",
          description: "expression with variable `t` being the elapsed time and `$input` the input."
        }
      ],
      tags: ["meta"],
      description: "Raw code node, expects floats between -1 and 1",
      compile: ({ vars: e, node: t, name: i }) => `let $input = ${e[0]}; 
const ${i} = (${t.value}); // raw`,
      examples: [
        `sine(4).range(.5,1)
.raw("(time*110%1*2-1)*$input")
.out()`
      ]
    }
  );
  var yt = u(
    "bytebeat",
    (e, t) => new c("bytebeat", t).withIns(f(e)),
    {
      ins: [
        { name: "t", description: "time in samples" },
        {
          name: "code",
          description: "bytebeat code with variable `t`"
        }
      ],
      tags: ["meta"],
      description: "Bytebeat node, expects numbers from 0 to 255",
      examples: [
        `time().mul(8000).bytebeat\`
// Fractalized Past
// by: lhphr
// from: https://dollchan.net/btb/res/3.html#69

(t>>10^t>>11)%5*((t>>14&3^t>>15&1)+1)*t%99+((3+(t>>14&3)-(t>>16&1))/3*t%99&64)
\`.out()`
      ],
      compile: ({ vars: e, node: t, name: i }) => `let t = ${e[0]}; 
const ${i} = ((${t.value}) & 255) / 127.5 - 1; // bytebeat`
    }
  );
  var ft = u(
    "floatbeat",
    (e, t) => new c("bytebeat", t).withIns(f(e)),
    {
      ins: [
        { name: "t", description: "time in samples" },
        {
          name: "code",
          description: "floatbeat code with variable `t`"
        }
      ],
      tags: ["meta"],
      description: "Raw code node, expects numbers from -1 to 1",
      compile: ({ vars: e, node: t, name: i }) => `let t = ${e[0]}; const ${i} = (${t.value}); // floatbeat`
    }
  );
  var gt = a("adsr", {
    ugen: "ADSRNode",
    tags: ["envelope"],
    description: "ADSR envelope",
    examples: [
      `impulse(1).perc(.5)
.adsr(.01, .1, .5, .1)
.mul(sine(220)).out()`
    ],
    ins: [
      { name: "gate", default: 0, description: "gate input" },
      { name: "att", default: 0.02, description: "attack time" },
      { name: "dec", default: 0.1, description: "decay time" },
      { name: "sus", default: 0.2, description: "sustain level" },
      { name: "rel", default: 0.1, description: "release time" }
    ],
    compile: ({
      vars: [e = 0, t = 0.02, i = 0.1, n2 = 0.2, l2 = 0.1],
      ...o
    }) => s[o.lang].defUgen(o, "time", e, t, i, n2, l2)
  });
  var Xt = g(
    "ar",
    (e = 0, t = 0.02, i = 0.1) => e.adsr(t, 0, 1, i),
    {
      tags: ["envelope"],
      description: "AR envelope",
      examples: ["impulse(1).ad(.01, .1).mul(sine(220)).out()"],
      ins: [
        { name: "trig", default: 0, description: "gate input" },
        { name: "att", default: 0.02, description: "attack time" },
        { name: "rel", default: 0.1, description: "release time" }
      ]
    }
  );
  var Zt = g(
    "ad",
    (e = 0, t = 0.02, i = 0.1) => e.adsr(t, i, 0, i),
    {
      tags: ["envelope"],
      description: "AD envelope",
      examples: ["impulse(1).ad(.01, .1).mul(sine(220)).out()"],
      ins: [
        { name: "trig", default: 0, description: "gate input" },
        { name: "att", default: 0.02, description: "attack time" },
        { name: "dec", default: 0.1, description: "decay time" }
      ]
    }
  );
  var bt = a("clock", {
    ugen: "Clock",
    internal: true,
    // impulse is the preferred way..
    tags: ["regular", "clock"],
    description: "Clock source, with tempo in BPM",
    examples: ["clock(120).clockdiv(16).mul(sine(220)).out()"],
    ins: [
      {
        name: "bpm",
        default: 120,
        description: "clock tempo in bpm (beats per minute)"
      }
    ],
    compile: ({ vars: [e = 120], ...t }) => s[t.lang].defUgen(t, e)
  });
  var xt = a("clockdiv", {
    ugen: "ClockDiv",
    tags: ["clock", "trigger"],
    description: "Clock signal divider",
    examples: ["impulse(8).clockdiv(2).ad(.1,.1).mul(sine(220)).out()"],
    ins: [
      { name: "clock", default: 0, description: "clock input" },
      { name: "divisor", default: 2, description: "tempo divisor" }
    ],
    compile: ({ vars: [e = 0, t = 2], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var Rt = a("distort", {
    ugen: "Distort",
    tags: ["fx", "distortion"],
    description: "Overdrive-style distortion",
    examples: [
      `sine(220)
.distort( saw(.5).range(0,1) )
.out()`
    ],
    ins: [
      { name: "in", default: 0 },
      { name: "amt", default: 0, description: "distortion amount" }
    ],
    compile: ({ vars: [e = 0, t = 0], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var O = a("noise", {
    ugen: "NoiseOsc",
    tags: ["source", "noise"],
    description: "White noise source",
    examples: ["noise().mul(.25).out()"],
    ins: [
      {
        name: "next",
        default: 1,
        description: "if 0, the noise will hold the previous value. defaults to 1."
      }
    ],
    compile: ({ lang: e, vars: [t = 1], ...i }) => s[e].defUgen(i, t)
  });
  var Lt = a("lcgnoise", {
    ugen: "LcgNoise",
    tags: ["source", "noise"],
    description: "Lcg white noise source.",
    examples: ["lcgnoise().mul(.25).out()"],
    ins: [
      {
        name: "next",
        default: 1,
        description: "if 0, the noise will hold the previous value. defaults to 1."
      },
      {
        name: "reset",
        default: 0,
        description: "if 1, the random number generator sequence will reset."
      }
    ],
    compile: ({ lang: e, vars: [t = 1, i = 0], ...n2 }) => s[e].defUgen(n2, t, i)
  });
  var Mt = a("pink", {
    ugen: "PinkNoise",
    tags: ["source", "noise"],
    description: "Pink noise source",
    examples: ["pink().mul(.5).out()"],
    ins: [],
    compile: ({ lang: e, ...t }) => s[e].defUgen(t)
  });
  var zt = a("brown", {
    ugen: "BrownNoiseOsc",
    tags: ["source", "noise"],
    description: "Brown noise source",
    examples: ["brown().out()"],
    ins: [],
    compile: ({ lang: e, ...t }) => s[e].defUgen(t)
  });
  var Vt = a("dust", {
    ugen: "DustOsc",
    tags: ["trigger", "noise", "source"],
    description: "Generates random impulses from 0 to +1.",
    examples: ["dust(200).out()"],
    ins: [
      { name: "density", default: 0, description: "average impulses per second" }
    ],
    compile: ({ vars: [e = 0], ...t }) => s[t.lang].defUgen(t, e)
  });
  var $ = a("impulse", {
    ugen: "ImpulseOsc",
    tags: ["regular", "trigger"],
    description: "Regular single sample impulses (0 - 1)",
    examples: ["impulse(10).out()"],
    ins: [
      { name: "freq", default: 0 },
      { name: "phase", default: 0 }
    ],
    compile: ({ vars: [e = 0, t = 0], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var Wt = a("saw", {
    ugen: "SawOsc",
    tags: ["regular", "waveform", "source"],
    description: "Sawtooth wave oscillator with anti aliasing",
    examples: ["saw(110).mul(.5).out()"],
    ins: [{ name: "freq", default: 0 }],
    compile: ({ vars: [e = 0], ...t }) => s[t.lang].defUgen(t, e)
  });
  var Yt = a("zaw", {
    ugen: "ZawOsc",
    tags: ["regular", "waveform", "source"],
    description: "Sawtooth wave oscillator with sharp edges. Use saw for anti aliased variant.",
    examples: ["zaw(110).mul(.5).out()"],
    ins: [{ name: "freq", default: 0 }],
    compile: ({ vars: [e = 0], ...t }) => s[t.lang].defUgen(t, e)
  });
  var Nt = a("sine", {
    tags: ["regular", "waveform", "source"],
    ugen: "SineOsc",
    description: "Sine wave oscillator",
    examples: ["sine(220).out()"],
    ins: [
      { name: "freq", default: 0 },
      { name: "sync", default: 0, description: "sync input" },
      { name: "phase", default: 0, description: "phase offset" }
    ],
    compile: ({ vars: [e = 0, t = 0, i = 0], ...n2 }) => s[n2.lang].defUgen(n2, e, t, i)
  });
  var Ht = a("tri", {
    ugen: "TriOsc",
    tags: ["regular", "waveform", "source"],
    description: "Triangle wave oscillator",
    examples: ["tri(220).out()"],
    ins: [{ name: "freq", default: 0 }],
    compile: ({ vars: [e = 0], ...t }) => s[t.lang].defUgen(t, e)
  });
  var St = a("pulse", {
    ugen: "PulseOsc",
    tags: ["regular", "waveform", "source"],
    description: "Pulse wave oscillator",
    examples: ["pulse(220, sine(.1).range(.1,.5)).mul(.5).out()"],
    ins: [
      { name: "freq", default: 0 },
      { name: "pw", default: 0.5, description: "pulse width 0 - 1" }
    ],
    compile: ({ vars: [e = 0, t = 0.5], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var Tt = a("slide", {
    ugen: "Slide",
    tags: ["fx"],
    internal: true,
    description: "Slide/portamento node",
    examples: [
      `impulse(2).seq(55,110,220,330)
.slide(4).sine().out()`
    ],
    ins: [
      { name: "in", default: 0 },
      { name: "rate", default: 1 }
    ],
    compile: ({ vars: [e = 0, t = 1], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var wt = a("lag", {
    ugen: "Lag",
    tags: ["fx"],
    description: "Smoothes a signal. Good for slide / portamento effects.",
    examples: [
      `impulse(2).seq(220,330,440,550)
.lag(.4).sine().out()`
    ],
    ins: [
      { name: "in", default: 0 },
      { name: "rate", default: 1, description: "60 dB lag time in seconds" }
    ],
    compile: ({ vars: [e = 0, t = 1], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var Kt = a("slew", {
    ugen: "Slew",
    tags: ["fx"],
    description: "Limits the slope of an input signal. The slope is expressed in units per second.",
    examples: ["pulse(800).slew(4000, 4000).out()"],
    ins: [
      { name: "in", default: 0 },
      {
        name: "up",
        default: 1,
        description: "Maximum upward slope in units per second"
      },
      {
        name: "dn",
        default: 1,
        description: "Maximum downward slope in units per second"
      }
    ],
    compile: ({ vars: [e = 0, t = 1, i = 1], ...n2 }) => s[n2.lang].defUgen(n2, e, t, i)
  });
  var D = a("filter", {
    ugen: "Filter",
    tags: ["fx", "filter"],
    internal: true,
    description: "Two-pole low-pass filter",
    examples: ["saw(55).lpf( sine(1).range(.4,.8) ).out()"],
    ins: [
      { name: "in", default: 0 },
      { name: "cutoff", default: 1 },
      { name: "reso", default: 0 }
    ],
    compile: ({ vars: [e = 0, t = 1, i = 0], ...n2 }) => s[n2.lang].defUgen(n2, e, t, i)
  });
  var Ct = a("fold", {
    ugen: "Fold",
    tags: ["fx", "distortion", "limiter"],
    description: 'Distort incoming audio signal by "folding"',
    examples: [
      `sine(55)
.fold( sine(.5).range(0.2,4) )
.out()`
    ],
    ins: [
      { name: "in", default: 0 },
      { name: "rate", default: 0 }
    ],
    compile: ({ vars: [e = 0, t = 0], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var vt = a("seq", {
    ugen: "Sequence",
    tags: ["sequencer"],
    description: "Trigger controlled sequencer",
    examples: [
      `impulse(2).seq(220,330,440,550)
.sine().out()`
    ],
    ins: [
      { name: "trig", default: 0 },
      { name: "step", default: 0, dynamic: true, description: "step inputs" }
      // 1-Infinity of steps
    ],
    compile: ({ vars: e, ...t }) => s[t.lang].defUgen(t, ...e)
  });
  var It = a("delay", {
    ugen: "Delay",
    tags: ["fx"],
    description: "Delay line node",
    examples: [
      `impulse(1).ad(.01,.2).mul(sine(220))
.add(x=>x.delay(.1).mul(.8)).out()`
    ],
    ins: [
      { name: "in", default: 0 },
      { name: "time", default: 0 }
    ],
    compile: ({ vars: [e = 0, t = 0], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var Ut = a("hold", {
    ugen: "Hold",
    tags: ["fx"],
    description: "Sample and hold",
    examples: [
      `noise().hold(impulse(2))
.range(220,880).sine().out()`
    ],
    ins: [
      { name: "in", default: 0 },
      { name: "trig", default: 0 }
    ],
    compile: ({ vars: [e = 0, t = 0], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var kt = a("midifreq", {
    ugen: "MidiFreq",
    tags: ["external", "midi"],
    description: "Outputs frequency of midi note in. Multiple instances will do voice allocation",
    examples: ["midifreq().sine().out()"],
    ins: [
      {
        name: "channel",
        default: -1,
        description: "Channel filter. Defaults to all channels"
      }
    ],
    compile: ({ vars: [e = -1], ...t }) => s[t.lang].defUgen(t, e)
  });
  var Pt = a("midigate", {
    ugen: "MidiGate",
    tags: ["external", "midi"],
    description: "outputs gate of midi note in. Multiple instances will do voice allocation",
    examples: ["midigate().lag(1).mul(sine(220)).out()"],
    ins: [{ name: "channel", default: -1 }],
    compile: ({ vars: [e = -1], ...t }) => s[t.lang].defUgen(t, e)
  });
  var Ft = a("midivel", {
    ugen: "MidiVel",
    tags: ["external", "midi"],
    description: "outputs velocity of midi note in. Multiple instances will do voice allocation",
    examples: [
      "midigate().ar(0.01,0.2).mul(saw(midifreq())).mul(midivel()).mul(.8).out()"
    ],
    ins: [{ name: "channel", default: -1 }],
    compile: ({ vars: [e = -1], ...t }) => s[t.lang].defUgen(t, e)
  });
  var Jt = a("midicc", {
    ugen: "MidiCC",
    tags: ["external", "midi"],
    description: "Outputs bipolar value of given midi cc number. initValue can be set to be the output before getting first cc message.",
    examples: ["midicc(74).range(100,200).sine().out()"],
    ins: [
      { name: "ccnumber", default: -1 },
      { name: "channel", default: -1 },
      { name: "initValue", default: -1 }
      // could not name it "default" because syntax error
    ],
    compile: ({ vars: [e = -1, t = -1], ...i }) => s[i.lang].defUgen(i, e, t)
  });
  var K = a("cc", {
    ugen: "CC",
    tags: ["external"],
    description: "CC control",
    ins: [
      { name: "id", default: 0 },
      { name: "value", default: 0 }
    ],
    compile: ({ vars: [e], ...t }) => s[t.lang].defUgen(t, e)
  });
  var jt = a("audioin", {
    ugen: "AudioIn",
    tags: ["source", "external"],
    description: "External Audio Input, depends on your system input",
    examples: ["audioin().add(x=>x.delay(.1).mul(.8)).out()"],
    ins: [],
    compile: (e) => s[e.lang].defUgen(e, "input")
  });
  var H = a("log", {
    tags: ["math"],
    description: "calculates the logarithm (base 10) of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].log(e))
  });
  var A = a("exp", {
    tags: ["math"],
    description: "raises e to the power of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].exp(e))
  });
  var Qt = a("pow", {
    tags: ["math"],
    description: "raises the input to the given power",
    ins: [{ name: "in" }, { name: "power" }],
    compile: ({ vars: [e = 0, t = 1], name: i, lang: n2 }) => s[n2].def(i, s[n2].pow(e, t))
  });
  var q = a("sin", {
    tags: ["math"],
    description: "calculates the sine of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].defSin(e))
  });
  var _ = a("cos", {
    tags: ["math"],
    description: "calculates the cosine of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].defCos(e))
  });
  var Bt = a("tan", {
    tags: ["math"],
    description: "calculates the tan of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].defTan(e))
  });
  var Et = a("acos", {
    tags: ["math"],
    description: "calculates the acos of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].defAcos(e))
  });
  var Ot = a("asin", {
    tags: ["math"],
    description: "calculates the asin of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].defAsin(e))
  });
  var $t = a("atan", {
    tags: ["math"],
    description: "calculates the atan of the input signal",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].defAtan(e))
  });
  var Dt = a("mul", {
    tags: ["math"],
    description: "Multiplies the given signals.",
    examples: ["sine(220).mul( sine(4).range(.25,1) ).out()"],
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, e.join(" * ") || 0)
  });
  var C = a("add", {
    tags: ["math"],
    description: "sums the given signals",
    examples: ["n([0,3,7,10]).add(60).midinote().sine().mix(2).out()"],
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, e.join(" + ") || 0)
  });
  var At = a("div", {
    tags: ["math"],
    description: "adds the given signals",
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, e.join(" / ") || 0)
  });
  var qt = a("sub", {
    tags: ["math"],
    description: "subtracts the given signals",
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, e.join(" - ") || 0)
  });
  var _t = a("mod", {
    tags: ["math"],
    description: "calculates the modulo",
    examples: ["add(x=>x.add(.003).mod(1)).out()"],
    ins: [{ name: "in" }, { name: "modulo" }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, s[i].mod(...e) || 0)
  });
  var ei = a("abs", {
    tags: ["math"],
    description: "returns the absolute value of the signal",
    ins: [{ name: "in" }],
    examples: ["sine(440).abs().out()"],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].abs(e))
  });
  var ti = a("round", {
    tags: ["math"],
    description: "Rounds the signal to the nearest integer",
    ins: [{ name: "in" }],
    examples: ["sine(440.5).round().out()"],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].round(e))
  });
  var ii = a("clamp", {
    tags: ["math"],
    description: "Clamps the signal to stay within the given range",
    ins: [{ name: "in" }, { name: "min" }, { name: "max" }],
    examples: ["sine(440.5).clamp(-.6,.6).out()"],
    compile: ({ vars: [e = 0, t = -1, i = 1], name: n2, lang: l2 }) => {
      const o = s[l2].min(t, i), d2 = s[l2].max(t, i), G4 = s[l2].min(s[l2].max(e, o), d2);
      return s[l2].def(n2, G4);
    }
  });
  var ni = a("floor", {
    tags: ["math"],
    description: "Rounds the signal down",
    ins: [{ name: "in" }],
    examples: ["sine(440.5).floor().out()"],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].floor(e))
  });
  var si = a("ceil", {
    tags: ["math"],
    description: "Rounds the signal up",
    ins: [{ name: "in" }],
    examples: ["sine(440.5).ceil().out()"],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].ceil(e))
  });
  var li = a("sign", {
    tags: ["math"],
    description: "Returns 1 if positive and -1 if negative. uses Math.sign",
    ins: [{ name: "in" }],
    examples: ["sine(440.5).ceil().out()"],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, s[i].sign(e))
  });
  var ai = a("min", {
    tags: ["math"],
    description: "returns the minimum of the given signals",
    examples: [
      "impulse(4).apply(x => min(x.seq(0,3,2), x.seq(0,7,0,5,0)).add(48).midinote().sine()).out()"
    ],
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, e.reduce(s[i].min) || 0)
  });
  var oi = a("max", {
    tags: ["math"],
    description: "returns the maximum of the given signals",
    examples: [
      "impulse(4).apply(x => max(x.seq(0,3,2), x.seq(0,7,0,5,0)).add(48).midinote().sine()).out()"
    ],
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, e.reduce(s[i].max) || 0)
  });
  var di = a("argmin", {
    tags: ["math"],
    description: "returns the index of the minimum of the given signals",
    examples: [
      "argmin(saw(1), saw(3), saw(5)).mul(12).add(48).midinote().sine().out()"
    ],
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(
      t,
      s[i].pair_b(
        e.map(s[i].pair_make).reduce(s[i].pair_a_min)
      ) || 0
    )
  });
  var ci = a("argmax", {
    tags: ["math"],
    description: "returns the index of the maximum of the given signals",
    examples: [
      "argmax(saw(1), saw(3), saw(5)).mul(12).add(48).midinote().sine().out()"
    ],
    ins: [{ name: "in", dynamic: true }],
    compile: ({ vars: e, name: t, lang: i }) => s[i].def(
      t,
      s[i].pair_b(
        e.map(s[i].pair_make).reduce(s[i].pair_a_max)
      ) || 0
    )
  });
  var ee = a("greater", {
    tags: ["logic"],
    description: "returns 1 if input is greater then threshold",
    ins: [{ name: "in" }, { name: "threshold" }],
    examples: [
      `greater(sine(1),0)
.bipolar().range(100,200)
.sine().out()`
    ],
    compile: ({ vars: [e = 0, t = 0], name: i, lang: n2 }) => s[n2].def(i, `${e} > ${t}`)
  });
  var te = a("lower", {
    tags: ["logic"],
    description: "returns 1 if input is lower then threshold",
    ins: [{ name: "in" }, { name: "threshold" }],
    examples: [
      `lower(sine(1),0)
.bipolar().range(100,200)
.sine().out()`
    ],
    compile: ({ vars: [e = 0, t = 0], name: i, lang: n2 }) => s[n2].def(i, `${e} < ${t}`)
  });
  var pi = ee;
  var ui = te;
  var mi = a("xor", {
    tags: ["logic"],
    description: "returns 1 if exactly one of the inputs is 1",
    ins: [{ name: "a" }, { name: "b" }],
    compile: ({ vars: [e = 0, t = 0], name: i, lang: n2 }) => s[n2].def(i, `${e} != ${t} ? 1 : 0`)
  });
  var ri = a("and", {
    tags: ["logic"],
    description: "returns 1 if both inputs are 1",
    ins: [{ name: "a" }, { name: "b" }],
    compile: ({ vars: [e = 0, t = 0], name: i, lang: n2 }) => s[n2].def(i, `${e} && ${t} ? 1 : 0`)
  });
  var hi = a("or", {
    tags: ["logic"],
    description: "returns 1 if one or both inputs are 1",
    ins: [{ name: "a" }, { name: "b" }],
    compile: ({ vars: [e = 0, t = 0], name: i, lang: n2 }) => s[n2].def(i, `${e} || ${t} ? 1 : 0`)
  });
  var Gi = a("not", {
    tags: ["logic"],
    description: "returns 1 if input is 0, otherwise 0",
    ins: [{ name: "in" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, `(${e} === 0 ? 1 : 0)`)
  });
  var yi = a("bool", {
    tags: ["logic"],
    description: "returns 1 signal is non zero. inspired by genish",
    ins: [{ name: "a" }],
    compile: ({ vars: [e = 0], name: t, lang: i }) => s[i].def(t, `(${e} === 0 ? 0 : 1)`)
  });
  var fi = a("ifelse", {
    tags: ["logic"],
    description: "if control is 1, a is returned, otherwise b",
    ins: [{ name: "control" }, { name: "a" }, { name: "b" }],
    compile: ({ vars: [e = 0, t = 0, i = 0], name: n2, lang: l2 }) => s[l2].def(n2, `(${e} === 1 ? ${t} : ${i})`),
    examples: ["ifelse(pulse(1), sine(220), sine(330)).out()"]
  });
  var gi = a("range", {
    tags: ["math"],
    description: "Scales the incoming bipolar value to the given range.",
    examples: ["sine(.5).range(.25,1).mul(sine(440)).out()"],
    ins: [{ name: "in" }, { name: "min" }, { name: "max" }],
    compile: ({ vars: e, name: t, lang: i }) => {
      const [n2, l2, o, d2 = 1] = e, G4 = `((${n2} + 1) * 0.5)`, p2 = d2 === 1 ? G4 : s[i].pow(G4, d2);
      return s[i].def(t, `${p2} * (${o} - ${l2}) + ${l2}`);
    }
  });
  var Xi = a("remap", {
    ugen: "Remap",
    tags: ["math"],
    description: "Remaps input from one value range to another",
    ins: [
      { name: "in" },
      { name: "inmin" },
      { name: "inmax" },
      { name: "outmin" },
      { name: "outmax" }
    ],
    // examples: [`sine(440).abs().out()`],
    compile: ({
      vars: [e = 0, t = -1, i = 1, n2 = -1, l2 = 1],
      ...o
    }) => s[o.lang].defUgen(o, e, t, i, n2, l2)
  });
  var Zi = a("thru", {
    compile: ({ name: e, vars: t, lang: i }) => s[i].def(e, t[0], "thru")
  });
  var bi = g(
    "rangex",
    (e, t, i) => {
      let n2 = H(t), l2 = H(i).sub(n2), d2 = e.unipolar().mul(l2).add(n2);
      return A(d2);
    },
    {
      tags: ["math"],
      description: "exponential range",
      ins: [{ name: "in" }, { name: "min" }, { name: "max" }],
      examples: ["sine([1,3]).rangex(100, 2e3).sine().out()"]
    }
  );
  var xi = a("midinote", {
    compile: ({ vars: [e], name: t, lang: i }) => s[i].def(t, s[i].midinote(e)),
    tags: ["math"],
    description: "convert midi number to frequency",
    ins: [{ name: "midi" }],
    examples: [
      `impulse(4).seq(0,3,7,12).add(60)
.midinote().sine().out()`
    ]
  });
  var Ri = a("src", {
    internal: true,
    compile: ({ vars: [e = 0], name: t, lang: i, ...n2 }) => s[i].def(t, n2.getSource(e), `read source ${e}`)
  });
  var Li = a("output", {
    internal: true,
    ugen: "Output",
    compile: ({ vars: [e, t = 0], name: i, lang: n2, ...l2 }) => {
      const o = l2.getOutput(t), d2 = l2.getSource(t);
      return [
        s[n2].def(o, [o, e].join(" + "), `+ output ${t}`),
        s[n2].def(d2, o, `write source ${t}`)
      ].join(`
`);
    }
  });
  var ie = a("poly");
  var ne = f(Math.PI);
  var Mi = u(
    "fork",
    (e, t = 1) => ie(...Array.from({ length: t }, () => e.clone())),
    {
      ins: [{ name: "in" }, { name: "times" }],
      tags: ["multi-channel"],
      description: "split the signal into n channels",
      examples: ["dust(4).fork(2).adsr(.1).mul(sine(220)).out()"]
    }
  );
  var zi = g("perc", (e, t) => e.adsr(0, 0, 1, t), {
    tags: ["envelope"],
    description: "percussive envelope. usable with triggers or gates",
    ins: [{ name: "gate" }, { name: "release" }],
    examples: ["impulse(4).perc(.1).mul( pink() ).out()"]
  });
  var Vi = g(
    "hpf",
    (e, t, i = 0) => e.sub(e.lpf(t, i)),
    {
      ins: [{ name: "in" }, { name: "cutoff" }, { name: "reso" }],
      description: "high pass filter",
      tags: ["fx", "filter"],
      examples: ["tri([220,331,442]).mix().hpf(sine(.5).range(0,.9)).out()"]
    }
  );
  var Wi = g("lpf", D, {
    ins: [{ name: "in" }, { name: "cutoff" }, { name: "reso" }],
    description: "low pass filter",
    tags: ["fx", "filter"],
    examples: ["saw(55).lpf( sine(1).range(.4,.8) ).out()"]
  });
  var Yi = a("bpf", {
    ugen: "BPF",
    ins: [{ name: "in" }, { name: "cutoff" }, { name: "reso" }],
    description: "high pass filter",
    tags: ["fx", "filter"],
    compile: ({ vars: [e = 0, t = 1, i = 0], ...n2 }) => s[n2.lang].defUgen(n2, e, t, i)
  });
  var Ni = g("lfnoise", (e) => O().hold($(e)), {
    ins: [{ name: "freq" }],
    description: "low frequency stepped noise.",
    tags: ["regular", "noise"],
    examples: ["lfnoise(4).range(200,800).sine().out()"]
  });
  var Hi = g(
    "bipolar",
    (e) => f(e).mul(2).sub(1),
    {
      ins: [{ name: "in" }],
      description: "convert unipolar [0,1] signal to bipolar [-1,1]",
      tags: ["math"]
      // examples: [], // tbd
    }
  );
  var Si = g(
    "unipolar",
    (e) => f(e).add(1).div(2),
    {
      ins: [{ name: "in" }],
      description: "convert bipolar [-1,1] signal to unipolar [0,1]",
      tags: ["math"]
      // examples: [], // tbd
    }
  );
  var Ti = g(
    "pan",
    (e, t) => (t = f(t).add(1).mul(ne, 0.25), e.mul([_(t), q(t)])),
    {
      ins: [
        { name: "in" },
        {
          name: "pos",
          description: "bipolar position: -1 = left, 0 = center, 1 = right"
        }
      ],
      description: "pans signal to stereo position. splits signal path in 2",
      tags: ["multi-channel"],
      examples: ["sine(220).pan(sine(.25)).out()"]
    }
  );
  var wi = a("pick", {
    tags: ["multi-channel"],
    ugen: "Pick",
    description: "Pick",
    ins: [{ name: "index" }, { name: "inputs", dynamic: true }],
    description: "picks input of given index",
    examples: [
      `sine(.25).range(0,2).round()
.pick(...sine([220,330,440]).ins)
.out()`
    ],
    compile: ({ vars: e, ...t }) => s[t.lang].defUgen(t, ...e)
  });
  var Ki = a("clip", {
    tags: ["fx"],
    ugen: "Clip",
    description: "Hard limits the signal between lo and hi.",
    ins: [{ name: "input" }, { name: "lo" }, { name: "hi" }],
    compile: ({ vars: [e = 0, t = -1, i = 1], ...n2 }) => s[n2.lang].defUgen(n2, e, t, i)
  });
  var Ci = a("trig", {
    tags: ["trigger"],
    ugen: "Trig",
    description: "Emits a trigger impulse whenever the signal becomes positive. Useful to turn gates into triggers.",
    ins: [
      { name: "input", default: 0 },
      { name: "lo", default: -1 },
      { name: "hi", default: 1 }
    ],
    compile: ({ vars: [e = 0, t = -1, i = 1], ...n2 }) => s[n2.lang].defUgen(n2, e, t, i),
    examples: [
      `pulse(2)
.trig() // comment out to hear difference
.ar(.01,.2)
.mul(sine(200)).out()`
    ]
  });
  var vi = a("qf", {
    tags: ["fx", "filter"],
    ugen: "BiquadFilter",
    description: "biQuad Filter.",
    ins: [
      { name: "input", default: 0 },
      {
        name: "type",
        default: 0,
        description: "filter type: 0 = lowpass, 1 = highpass, 2 = band pass, 3 = notch, 4 = allpass, 5 = peaking, 6 = lowshelf, 7 = highshelf"
      },
      { name: "freq", default: 500, description: "filter cutoff in Hz" },
      { name: "q", default: 1, description: "q factor" },
      { name: "gain", default: 1 }
    ],
    compile: ({ vars: e, ...t }) => s[t.lang].defUgen(t, ...e),
    examples: [
      `pink()
.qf(
 impulse(.5).seq(0,1,2,3,4,5,6,7), // type
  tri(0.5).rangex(100, 8000),  // freq
 10, // Q
 1, // gain (only relevant for types 5-7)
).div(4).out();`
    ]
  });
  var Ii = u(
    "qlpf",
    (e, t, i = 10) => e.qf(0, t, i),
    {
      description: "biQuad Low Pass Filter",
      ins: [
        { name: "input" },
        { name: "freq" },
        { name: "q", description: "resonance" }
      ],
      tags: ["fx", "filter"],
      examples: [
        `pink().qlpf(
  tri(0.5).rangex(100, 8000), // cutoff freq
  10 // Q
).out()`
      ]
    }
  );
  var Ui = u(
    "qhpf",
    (e, t, i = 10) => e.qf(1, t, i),
    {
      description: "biQuad High pass filter",
      ins: [
        { name: "input" },
        { name: "freq" },
        { name: "q", description: "resonance" }
      ],
      tags: ["fx", "filter"],
      examples: [
        `pink().qhpf(
  tri(0.5).rangex(100, 8000), // cutoff freq
  10 // Q
).out()`
      ]
    }
  );
  var ki = u(
    "qbpf",
    (e, t, i = 10) => e.qf(2, t, i),
    {
      description: "biQuad Band Pass Filter",
      ins: [
        { name: "input" },
        { name: "freq" },
        { name: "q", description: "resonance" }
      ],
      tags: ["fx", "filter"],
      examples: [
        `pink().qbpf(
  tri(0.5).rangex(100, 8000), // cutoff freq
  10 // Q
).out()`
      ]
    }
  );
  var Pi = u(
    "qnf",
    (e, t, i = 10) => e.qf(3, t, i),
    {
      description: "biQuad Notch Filter",
      ins: [
        { name: "input" },
        { name: "freq" },
        { name: "q", description: "resonance" }
      ],
      tags: ["fx", "filter"],
      examples: [
        `pink().qnf(
  tri(0.5).rangex(100, 8000), // cutoff freq
  10 // Q
).out()`
      ]
    }
  );
  var Fi = u(
    "qapf",
    (e, t, i = 10) => e.qf(3, t, i),
    {
      description: "biQuad All Pass Filter",
      ins: [
        { name: "input" },
        { name: "freq" },
        { name: "q", description: "resonance" }
      ],
      tags: ["fx", "filter"],
      examples: [
        `impulse(1).qapf(
  tri(0.5).rangex(100, 8000), // cutoff freq
  10 // Q
).out()`
      ]
    }
  );
  var Ji = u(
    "split",
    (e, t) => e.type !== "poly" ? t([e]) : t(e.ins),
    {
      ins: [{ name: "input" }, { name: "fn" }],
      tags: ["multi-channel"],
      description: "apply fn to an array of signals, one for each channel in input",
      examples: ["sine([220,330,550]).split(chs => add(...chs)).out()"]
    }
  );
  var ji = u(
    "mix",
    (e, t = 1) => {
      if ([1, 2].includes(t) || (t = 2, console.warn("mix only supports 1 or 2 channels atm.. falling back to 2")), e.type !== "poly")
        return e;
      if (t === 2) {
        const i = e.ins.map((n2, l2, o) => {
          const G4 = (l2 / (o.length - 1) * 2 - 1 + 1) * Math.PI / 4;
          return n2.mul([Math.cos(G4), Math.sin(G4)]).inherit(e);
        });
        return C(...i);
      }
      return e.ins = e.ins.map((i) => i.inherit(e)), x("mix").withIns(...e.ins);
    },
    {
      compile: ({ vars: e, name: t, lang: i }) => s[i].def(t, `(${e.join(" + ")})`),
      description: `mixes down multiple channels. Useful to make sure you get a mono or stereo signal out at the end. 
When mixing down to 2 channels, the input channels are equally distributed over the stereo image, e.g. 3 channels are panned [-1,0,1]`,
      ins: [
        { name: "in" },
        {
          name: "channels",
          default: 1,
          description: "how many channels to mix down to. Only supports 1 and 2"
        }
      ],
      tags: ["multi-channel"],
      examples: ["sine([220,330,440]).mix(2).out()"]
    }
  );
  c.prototype.feedback = function(e) {
    return this.add(e);
  };
  var Qi = (e) => C(e);
  var Bi = f;
  var Ei = f;
  var Oi = g("mouseX", () => K("mouseX"), {
    ins: [],
    description: "X position of mouse, bipolar range",
    tags: ["external"],
    examples: ["mouseX.range(100,800).sine().out()"]
  });
  var $i = Oi();
  var Di = g("mouseY", () => K("mouseY"), {
    ins: [],
    description: "Y position of mouse, bipolar range",
    tags: ["external"],
    examples: ["mouseY.range(800,100).sine().out()"]
  });
  var Ai = Di();
  var qi = u(
    "scope",
    (e, t) => {
      let i = 1;
      e.type === "poly" && (i = e.ins.length);
      const n2 = getNode("scope", e, t, i);
      return n2.type !== "poly" ? (n2.ins.push({ type: "n", value: 0, ins: [] }), n2) : (n2.ins.forEach((l2, o) => l2.ins.push({ type: "n", value: o, ins: [] })), n2);
    },
    {
      ugen: "Scope",
      description: "renders an an oscilloscope of the current point in the graph. expects values between -1 and 1. warning: this feature is still experimental! when using it, make sure to not switch tabs, as it might fry your browser.",
      compile: ({ vars: [e, t, i, n2], ...l2 }) => w(l2, e, t, i, n2)
    }
  );
  var P2 = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
    __proto__: null,
    B: Bi,
    PI: ne,
    _: Ei,
    abs: ei,
    acos: Et,
    ad: Zt,
    add: C,
    adsr: gt,
    and: ri,
    ar: Xt,
    argmax: ci,
    argmin: di,
    asin: Ot,
    atan: $t,
    audioin: jt,
    bipolar: Hi,
    bool: yi,
    bpf: Yi,
    brown: zt,
    bytebeat: yt,
    cc: K,
    ceil: si,
    clamp: ii,
    clip: Ki,
    clock: bt,
    clockdiv: xt,
    cos: _,
    delay: It,
    distort: Rt,
    div: At,
    dust: Vt,
    exp: A,
    feedback: Qi,
    filter: D,
    floatbeat: ft,
    floor: ni,
    fold: Ct,
    fork: Mi,
    greater: ee,
    gt: pi,
    hold: Ut,
    hpf: Vi,
    ifelse: fi,
    impulse: $,
    lag: wt,
    lfnoise: Ni,
    log: H,
    lower: te,
    lpf: Wi,
    lt: ui,
    max: oi,
    midicc: Jt,
    midifreq: kt,
    midigate: Pt,
    midinote: xi,
    midivel: Ft,
    min: ai,
    mix: ji,
    mod: _t,
    mouseX: $i,
    mouseY: Ai,
    mul: Dt,
    noise: O,
    not: Gi,
    or: hi,
    output: Li,
    pan: Ti,
    perc: zi,
    pick: wi,
    pink: Mt,
    poly: ie,
    pow: Qt,
    pulse: St,
    qapf: Fi,
    qbpf: ki,
    qf: vi,
    qhpf: Ui,
    qlpf: Ii,
    qnf: Pi,
    range: gi,
    rangex: bi,
    raw: Gt,
    registerUgen: E,
    remap: Xi,
    rng: Lt,
    round: ti,
    saw: Wt,
    scope: qi,
    seq: vt,
    sign: li,
    sin: q,
    sine: Nt,
    slew: Kt,
    slide: Tt,
    split: Ji,
    src: Ri,
    sub: qt,
    tan: Bt,
    thru: Zi,
    time: ht,
    tri: Ht,
    trig: Ci,
    unipolar: Si,
    xor: mi,
    zaw: Yt
  }, Symbol.toStringTag, { value: "Module" }));
  var en = class {
    constructor({
      onToggle: t,
      onToggleRecording: i,
      beforeEval: n2,
      transpiler: l2,
      localScope: o = false,
      outputNode: d2 = null
    } = {}) {
      this.outputNode = d2, this.audio = new Fe(this.outputNode), this.onToggle = t, this.transpiler = l2, this.onToggleRecording = i, this.beforeEval = n2, this.localScope = o, typeof window < "u" && (o || (Object.assign(globalThis, k), Object.assign(globalThis, P2), Object.assign(globalThis, U), Object.assign(globalThis, { repl: this })), window.addEventListener("message", (p2) => {
        p2.data.type === "KABELSALAT_SET_CONTROL" && this.audio.setControl(p2.data.id, p2.data.value);
      }));
      const G4 = this;
      c.prototype.spawn = function(p2 = [0, 1], m3) {
        G4.audio.spawn(this.output(p2).exit(), m3);
      };
    }
    registerUgen(t, i) {
      return this.audio.registerUgen(i), E(t, i.name);
    }
    evaluate(t) {
      this.localScope || (Object.assign(globalThis, { audio: this.audio }), Object.assign(globalThis, {
        addUgen: this.registerUgen.bind(this)
      }));
      let i;
      this.transpiler ? i = this.transpiler(t) : i = { output: t }, this.beforeEval?.(i);
      let n2;
      return this.localScope && (n2 = {
        ...k,
        ...P2,
        ...U,
        audio: this.audio,
        addUgen: this.registerUgen.bind(this),
        repl: this
      }), j(i.output, n2);
    }
    async play(t) {
      await this.audio.init(), t.ins.length && this.audio.spawn(t), this.onToggle?.(true);
    }
    run(t) {
      const i = this.evaluate(t);
      this.play(i);
    }
    stop() {
      this.stopRecording(), this.audio.stop(), this.onToggle?.(false);
    }
    record() {
      this.audio.record(), this.onToggleRecording?.(true);
    }
    stopRecording() {
      this.audio.stopRecording(), this.onToggleRecording?.(false);
    }
  };

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/core/dist/index.mjs
  var import_meta = {};
  var oe2 = "strudel.log";
  var Qe2 = 1e3;
  var Ut2;
  var Xt2;
  function zt2(t, e = "cyclist") {
    console.error(t), E2(`[${e}] error: ${t.message}`);
  }
  function E2(t, e, n2 = {}) {
    let s2 = performance.now();
    Ut2 === t && s2 - Xt2 < Qe2 || (Ut2 = t, Xt2 = s2, console.log(`%c${t}`, "background-color: black;color:white;border-radius:15px"), typeof document < "u" && typeof CustomEvent < "u" && document.dispatchEvent(
      new CustomEvent(oe2, {
        detail: {
          message: t,
          type: e,
          data: n2
        }
      })
    ));
  }
  E2.key = oe2;
  var Yf = (t) => /^[a-gA-G][#bsf]*[0-9]*$/.test(t);
  var Mt2 = (t) => /^[a-gA-G][#bsf]*-?[0-9]*$/.test(t);
  var Ue2 = (t) => {
    if (typeof t != "string")
      return [];
    const [e, n2 = "", s2] = t.match(/^([a-gA-G])([#bsf]*)(-?[0-9]*)$/)?.slice(1) || [];
    return e ? [e, n2, s2 ? Number(s2) : void 0] : [];
  };
  var Xe2 = { c: 0, d: 2, e: 4, f: 5, g: 7, a: 9, b: 11 };
  var Ke2 = { "#": 1, b: -1, s: 1, f: -1 };
  var Ye2 = (t) => t?.split("").reduce((e, n2) => e + Ke2[n2], 0) || 0;
  var gt2 = (t, e = 3) => {
    const [n2, s2, r = e] = Ue2(t);
    if (!n2)
      throw new Error('not a note: "' + t + '"');
    const o = Xe2[n2.toLowerCase()], i = Ye2(s2);
    return (Number(r) + 1) * 12 + o + i;
  };
  var it2 = (t) => Math.pow(2, (t - 69) / 12) * 440;
  var Ze2 = (t) => 12 * Math.log(t / 440) / Math.LN2 + 69;
  var Zf = (t, e) => {
    if (typeof t != "object")
      throw new Error("valueToMidi: expected object value");
    let { freq: n2, note: s2 } = t;
    if (typeof n2 == "number")
      return Ze2(n2);
    if (typeof s2 == "string")
      return gt2(s2);
    if (typeof s2 == "number")
      return s2;
    if (!e)
      throw new Error("valueToMidi: expected freq or note to be set");
    return e;
  };
  var th = (t, e) => (t - e) * 1e3;
  var tn = (t) => it2(typeof t == "number" ? t : gt2(t));
  var en2 = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
  var eh = (t) => {
    const e = Math.floor(t / 12) - 1;
    return en2[t % 12] + e;
  };
  var bt2 = (t, e) => (t % e + e) % e;
  var nn = (t) => t.reduce((e, n2) => e + n2) / t.length;
  function sn(t, e = 0) {
    return isNaN(Number(t)) ? (E2(`"${t}" is not a number, falling back to ${e}`, "warning"), e) : t;
  }
  var nh = (t, e) => bt2(Math.round(sn(t ?? 0, 0)), e);
  var sh = (t) => {
    let { value: e, context: n2 } = t, s2 = e;
    if (typeof s2 == "object" && !Array.isArray(s2) && (s2 = s2.note || s2.n || s2.value, s2 === void 0))
      throw new Error(`cannot find a playable note for ${JSON.stringify(e)}`);
    if (typeof s2 == "number" && n2.type !== "frequency")
      s2 = it2(t.value);
    else if (typeof s2 == "number" && n2.type === "frequency")
      s2 = t.value;
    else if (typeof s2 != "string" || !Mt2(s2))
      throw new Error("not a note: " + JSON.stringify(s2));
    return s2;
  };
  var rh = (t) => {
    let { value: e, context: n2 } = t;
    if (typeof e == "object")
      return e.freq ? e.freq : tn(e.note || e.n || e.value);
    if (typeof e == "number" && n2.type !== "frequency")
      e = it2(t.value);
    else if (typeof e == "string" && Mt2(e))
      e = it2(gt2(t.value));
    else if (typeof e != "number")
      throw new Error("not a note or frequency: " + e);
    return e;
  };
  var rn = (t, e) => t.slice(e).concat(t.slice(0, e));
  var on = (...t) => t.reduce(
    (e, n2) => (...s2) => e(n2(...s2)),
    (e) => e
  );
  var oh = (...t) => on(...t.reverse());
  var lt2 = (t) => t.filter((e) => e != null);
  var G = (t) => [].concat(...t);
  var ot2 = (t) => t;
  var ch = (t, e) => t;
  var _t2 = (t, e) => Array.from({ length: e - t + 1 }, (n2, s2) => s2 + t);
  function w2(t, e, n2 = t.length) {
    const s2 = function r(...o) {
      if (o.length >= n2)
        return t.apply(this, o);
      {
        const i = function(...a2) {
          return r.apply(this, o.concat(a2));
        };
        return e && e(i, o), i;
      }
    };
    return e && e(s2, []), s2;
  }
  function ce2(t) {
    const e = Number(t);
    if (!isNaN(e))
      return e;
    if (Mt2(t))
      return gt2(t);
    throw new Error(`cannot parse as numeral: "${t}"`);
  }
  function ie2(t, e) {
    return (...n2) => t(...n2.map(e));
  }
  function L2(t) {
    return ie2(t, ce2);
  }
  function cn(t) {
    const e = Number(t);
    if (!isNaN(e))
      return e;
    const n2 = {
      pi: Math.PI,
      w: 1,
      h: 0.5,
      q: 0.25,
      e: 0.125,
      s: 0.0625,
      t: 1 / 3,
      f: 0.2,
      x: 1 / 6
    }[t];
    if (typeof n2 < "u")
      return n2;
    throw new Error(`cannot parse as fractional: "${t}"`);
  }
  var ih = (t) => ie2(t, cn);
  var ue2 = function(t, e) {
    return [e.slice(0, t), e.slice(t)];
  };
  var Pt2 = (t, e, n2) => e.map((s2, r) => t(s2, n2[r]));
  var un = function(t) {
    const e = [];
    for (let n2 = 0; n2 < t.length - 1; ++n2)
      e.push([t[n2], t[n2 + 1]]);
    return e;
  };
  var an = (t, e, n2) => Math.min(Math.max(t, e), n2);
  var ln = ["Do", "Reb", "Re", "Mib", "Mi", "Fa", "Solb", "Sol", "Lab", "La", "Sib", "Si"];
  var pn = [
    "Sa",
    "Re",
    "Ga",
    "Ma",
    "Pa",
    "Dha",
    "Ni"
  ];
  var fn = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Hb", "H"];
  var hn = [
    "Ni",
    "Pab",
    "Pa",
    "Voub",
    "Vou",
    "Ga",
    "Dib",
    "Di",
    "Keb",
    "Ke",
    "Zob",
    "Zo"
  ];
  var dn = [
    "I",
    "Ro",
    "Ha",
    "Ni",
    "Ho",
    "He",
    "To"
  ];
  var mn = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
  var uh = (t, e = "letters") => {
    const s2 = (e === "solfeggio" ? ln : e === "indian" ? pn : e === "german" ? fn : e === "byzantine" ? hn : e === "japanese" ? dn : mn)[t % 12], r = Math.floor(t / 12) - 1;
    return s2 + r;
  };
  function ah(t) {
    var e = {};
    return t.filter(function(n2) {
      return e.hasOwn(n2) ? false : e[n2] = true;
    });
  }
  function lh(t) {
    return t.sort().filter(function(e, n2, s2) {
      return !n2 || e != s2[n2 - 1];
    });
  }
  function yn(t) {
    return t.sort((e, n2) => e.compare(n2)).filter(function(e, n2, s2) {
      return !n2 || e.ne(s2[n2 - 1]);
    });
  }
  function wn(t) {
    const e = new TextEncoder().encode(t);
    return btoa(String.fromCharCode(...e));
  }
  function gn(t) {
    const e = new Uint8Array(
      atob(t).split("").map((s2) => s2.charCodeAt(0))
    );
    return new TextDecoder().decode(e);
  }
  function ph(t) {
    return encodeURIComponent(wn(t));
  }
  function fh(t) {
    return gn(decodeURIComponent(t));
  }
  function bn(t, e) {
    return Array.isArray(t) ? t.map(e) : Object.fromEntries(Object.entries(t).map(([n2, s2], r) => [n2, e(s2, n2, r)]));
  }
  function Kt2(t, e) {
    return t / e;
  }
  var _n = class {
    constructor({
      getTargetClockTime: e = vn,
      weight: n2 = 16,
      offsetDelta: s2 = 5e-3,
      checkAfterTime: r = 2,
      resetAfterTime: o = 8
    }) {
      this.offsetTime, this.timeAtPrevOffsetSample, this.prevOffsetTimes = [], this.getTargetClockTime = e, this.weight = n2, this.offsetDelta = s2, this.checkAfterTime = r, this.resetAfterTime = o, this.reset = () => {
        this.prevOffsetTimes = [], this.offsetTime = null, this.timeAtPrevOffsetSample = null;
      };
    }
    calculateOffset(e) {
      const n2 = this.getTargetClockTime(), s2 = n2 - this.timeAtPrevOffsetSample, r = n2 - e;
      if (s2 > this.resetAfterTime && this.reset(), this.offsetTime == null && (this.offsetTime = r), this.prevOffsetTimes.push(r), this.prevOffsetTimes.length > this.weight && this.prevOffsetTimes.shift(), this.timeAtPrevOffsetSample == null || s2 > this.checkAfterTime) {
        this.timeAtPrevOffsetSample = n2;
        const o = nn(this.prevOffsetTimes);
        Math.abs(o - this.offsetTime) > this.offsetDelta && (this.offsetTime = o);
      }
      return this.offsetTime;
    }
    calculateTimestamp(e, n2) {
      return this.calculateOffset(e) + n2;
    }
  };
  function hh() {
    return performance.now() * 1e-3;
  }
  function vn() {
    return Date.now() * 1e-3;
  }
  var kn = /* @__PURE__ */ new Map([
    ["control", "Control"],
    ["ctrl", "Control"],
    ["alt", "Alt"],
    ["shift", "Shift"],
    ["down", "ArrowDown"],
    ["up", "ArrowUp"],
    ["left", "ArrowLeft"],
    ["right", "ArrowRight"]
  ]);
  var rt2;
  function qn() {
    if (rt2 == null) {
      if (typeof window > "u")
        return;
      rt2 = {}, window.addEventListener("keydown", (t) => {
        rt2[t.key] = true;
      }), window.addEventListener("keyup", (t) => {
        rt2[t.key] = false;
      });
    }
    return { ...rt2 };
  }
  function ae(t, e = false) {
    return typeof t == "object" ? e ? JSON.stringify(t).slice(1, -1).replaceAll('"', "").replaceAll(",", " ") : JSON.stringify(t) : t;
  }
  Fraction.prototype.sam = function() {
    return this.floor();
  };
  Fraction.prototype.nextSam = function() {
    return this.sam().add(1);
  };
  Fraction.prototype.wholeCycle = function() {
    return new B2(this.sam(), this.nextSam());
  };
  Fraction.prototype.cyclePos = function() {
    return this.sub(this.sam());
  };
  Fraction.prototype.lt = function(t) {
    return this.compare(t) < 0;
  };
  Fraction.prototype.gt = function(t) {
    return this.compare(t) > 0;
  };
  Fraction.prototype.lte = function(t) {
    return this.compare(t) <= 0;
  };
  Fraction.prototype.gte = function(t) {
    return this.compare(t) >= 0;
  };
  Fraction.prototype.eq = function(t) {
    return this.compare(t) == 0;
  };
  Fraction.prototype.ne = function(t) {
    return this.compare(t) != 0;
  };
  Fraction.prototype.max = function(t) {
    return this.gt(t) ? this : t;
  };
  Fraction.prototype.maximum = function(...t) {
    return t = t.map((e) => new Fraction(e)), t.reduce((e, n2) => n2.max(e), this);
  };
  Fraction.prototype.min = function(t) {
    return this.lt(t) ? this : t;
  };
  Fraction.prototype.mulmaybe = function(t) {
    return t !== void 0 ? this.mul(t) : void 0;
  };
  Fraction.prototype.divmaybe = function(t) {
    return t !== void 0 ? this.div(t) : void 0;
  };
  Fraction.prototype.addmaybe = function(t) {
    return t !== void 0 ? this.add(t) : void 0;
  };
  Fraction.prototype.submaybe = function(t) {
    return t !== void 0 ? this.sub(t) : void 0;
  };
  Fraction.prototype.show = function() {
    return this.s * this.n + "/" + this.d;
  };
  Fraction.prototype.or = function(t) {
    return this.eq(0) ? t : this;
  };
  var m = (t) => Fraction(t);
  var Sn = (...t) => {
    if (t = lt2(t), t.length !== 0)
      return t.reduce((e, n2) => e.gcd(n2), m(1));
  };
  var Y2 = (...t) => {
    if (t = lt2(t), t.length === 0)
      return;
    const e = t.pop();
    return t.reduce(
      (n2, s2) => n2 === void 0 || s2 === void 0 ? void 0 : n2.lcm(s2),
      e
    );
  };
  var An = (t) => t instanceof Fraction;
  m._original = Fraction;
  var B2 = class _B {
    constructor(e, n2) {
      this.begin = m(e), this.end = m(n2);
    }
    get spanCycles() {
      const e = [];
      var n2 = this.begin;
      const s2 = this.end, r = s2.sam();
      if (n2.equals(s2))
        return [new _B(n2, s2)];
      for (; s2.gt(n2); ) {
        if (n2.sam().equals(r)) {
          e.push(new _B(n2, this.end));
          break;
        }
        const o = n2.nextSam();
        e.push(new _B(n2, o)), n2 = o;
      }
      return e;
    }
    get duration() {
      return this.end.sub(this.begin);
    }
    cycleArc() {
      const e = this.begin.cyclePos(), n2 = e.add(this.duration);
      return new _B(e, n2);
    }
    withTime(e) {
      return new _B(e(this.begin), e(this.end));
    }
    withEnd(e) {
      return new _B(this.begin, e(this.end));
    }
    withCycle(e) {
      const n2 = this.begin.sam(), s2 = n2.add(e(this.begin.sub(n2))), r = n2.add(e(this.end.sub(n2)));
      return new _B(s2, r);
    }
    intersection(e) {
      const n2 = this.begin.max(e.begin), s2 = this.end.min(e.end);
      if (!n2.gt(s2) && !(n2.equals(s2) && (n2.equals(this.end) && this.begin.lt(this.end) || n2.equals(e.end) && e.begin.lt(e.end))))
        return new _B(n2, s2);
    }
    intersection_e(e) {
      const n2 = this.intersection(e);
      if (n2 == null)
        throw "TimeSpans do not intersect";
      return n2;
    }
    midpoint() {
      return this.begin.add(this.duration.div(m(2)));
    }
    equals(e) {
      return this.begin.equals(e.begin) && this.end.equals(e.end);
    }
    show() {
      return this.begin.show() + " \u2192 " + this.end.show();
    }
  };
  var S2 = class _S {
    /*
          Event class, representing a value active during the timespan
          'part'. This might be a fragment of an event, in which case the
          timespan will be smaller than the 'whole' timespan, otherwise the
          two timespans will be the same. The 'part' must never extend outside of the
          'whole'. If the event represents a continuously changing value
          then the whole will be returned as None, in which case the given
          value will have been sampled from the point halfway between the
          start and end of the 'part' timespan.
          The context is to store a list of source code locations causing the event.
    
          The word 'Event' is more or less a reserved word in javascript, hence this
          class is named called 'Hap'.
          */
    constructor(e, n2, s2, r = {}, o = false) {
      this.whole = e, this.part = n2, this.value = s2, this.context = r, this.stateful = o, o && console.assert(typeof this.value == "function", "Stateful values must be functions");
    }
    get duration() {
      let e;
      return typeof this.value?.duration == "number" ? e = m(this.value.duration) : e = this.whole.end.sub(this.whole.begin), typeof this.value?.clip == "number" ? e.mul(this.value.clip) : e;
    }
    get endClipped() {
      return this.whole.begin.add(this.duration);
    }
    isActive(e) {
      return this.whole.begin <= e && this.endClipped >= e;
    }
    isInPast(e) {
      return e > this.endClipped;
    }
    isInNearPast(e, n2) {
      return n2 - e <= this.endClipped;
    }
    isInFuture(e) {
      return e < this.whole.begin;
    }
    isInNearFuture(e, n2) {
      return n2 < this.whole.begin && n2 > this.whole.begin - e;
    }
    isWithinTime(e, n2) {
      return this.whole.begin <= n2 && this.endClipped >= e;
    }
    wholeOrPart() {
      return this.whole ? this.whole : this.part;
    }
    withSpan(e) {
      const n2 = this.whole ? e(this.whole) : void 0;
      return new _S(n2, e(this.part), this.value, this.context);
    }
    withValue(e) {
      return new _S(this.whole, this.part, e(this.value), this.context);
    }
    hasOnset() {
      return this.whole != null && this.whole.begin.equals(this.part.begin);
    }
    hasTag(e) {
      return this.context.tags?.includes(e);
    }
    resolveState(e) {
      if (this.stateful && this.hasOnset()) {
        console.log("stateful");
        const n2 = this.value, [s2, r] = n2(e);
        return [s2, new _S(this.whole, this.part, r, this.context, false)];
      }
      return [e, this];
    }
    spanEquals(e) {
      return this.whole == null && e.whole == null || this.whole.equals(e.whole);
    }
    equals(e) {
      return this.spanEquals(e) && this.part.equals(e.part) && // TODO would == be better ??
      this.value === e.value;
    }
    show(e = false) {
      const n2 = typeof this.value == "object" ? e ? JSON.stringify(this.value).slice(1, -1).replaceAll('"', "").replaceAll(",", " ") : JSON.stringify(this.value) : this.value;
      var s2 = "";
      if (this.whole == null)
        s2 = "~" + this.part.show;
      else {
        var r = this.whole.begin.equals(this.part.begin) && this.whole.end.equals(this.part.end);
        this.whole.begin.equals(this.part.begin) || (s2 = this.whole.begin.show() + " \u21DC "), r || (s2 += "("), s2 += this.part.show(), r || (s2 += ")"), this.whole.end.equals(this.part.end) || (s2 += " \u21DD " + this.whole.end.show());
      }
      return "[ " + s2 + " | " + n2 + " ]";
    }
    showWhole(e = false) {
      return `${this.whole == null ? "~" : this.whole.show()}: ${ae(this.value, e)}`;
    }
    combineContext(e) {
      const n2 = this;
      return { ...n2.context, ...e.context, locations: (n2.context.locations || []).concat(e.context.locations || []) };
    }
    setContext(e) {
      return new _S(this.whole, this.part, this.value, e);
    }
    ensureObjectValue() {
      if (typeof this.value != "object")
        throw new Error(
          `expected hap.value to be an object, but got "${this.value}". Hint: append .note() or .s() to the end`,
          "error"
        );
    }
  };
  var ut2 = class _ut {
    constructor(e, n2 = {}) {
      this.span = e, this.controls = n2;
    }
    // Returns new State with different span
    setSpan(e) {
      return new _ut(e, this.controls);
    }
    withSpan(e) {
      return this.setSpan(e(this.span));
    }
    // Returns new State with added controls.
    setControls(e) {
      return new _ut(this.span, { ...this.controls, ...e });
    }
  };
  function Tn(t, e, n2) {
    if (e?.value !== void 0 && Object.keys(e).length === 1)
      return E2("[warn]: Can't do arithmetic on control pattern."), t;
    const s2 = Object.keys(t).filter((r) => Object.keys(e).includes(r));
    return Object.assign({}, t, e, Object.fromEntries(s2.map((r) => [r, n2(t[r], e[r])])));
  }
  w2((t, e) => t * e);
  w2((t, e) => e.map(t));
  function Cn(t, e = 60) {
    let n2 = 0, s2 = m(0), r = [""], o = "";
    for (; r[0].length < e; ) {
      const i = t.queryArc(n2, n2 + 1), a2 = i.filter((h) => h.hasOnset()).map((h) => h.duration), u3 = Sn(...a2), p2 = u3.inverse();
      r = r.map((h) => h + "|"), o += "|";
      for (let h = 0; h < p2; h++) {
        const [y3, g3] = [s2, s2.add(u3)], v2 = i.filter((O2) => O2.whole.begin.lte(y3) && O2.whole.end.gte(g3)), _5 = v2.length - r.length;
        _5 > 0 && (r = r.concat(Array(_5).fill(o))), r = r.map((O2, A4) => {
          const I3 = v2[A4];
          if (I3) {
            const P3 = I3.whole.begin.eq(y3) ? "" + I3.value : "-";
            return O2 + P3;
          }
          return O2 + ".";
        }), o += ".", s2 = s2.add(u3);
      }
      n2++;
    }
    return r.join(`
`);
  }
  var le = {};
  var xn = async (...t) => {
    const e = await Promise.allSettled(t), n2 = e.filter((s2) => s2.status === "fulfilled").map((s2) => s2.value);
    return e.forEach((s2, r) => {
      s2.status === "rejected" && console.warn(`evalScope: module with index ${r} could not be loaded:`, s2.reason);
    }), n2.forEach((s2) => {
      Object.entries(s2).forEach(([r, o]) => {
        globalThis[r] = o, le[r] = o;
      });
    }), n2;
  };
  function Bn(t, e = {}) {
    const { wrapExpression: n2 = true, wrapAsync: s2 = true } = e;
    n2 && (t = `{${t}}`), s2 && (t = `(async ()=>${t})()`);
    const r = `"use strict";return (${t})`;
    return Function(r)();
  }
  var On = async (t, e, n2) => {
    let s2 = {};
    if (e) {
      const i = e(t, n2);
      t = i.output, s2 = i;
    }
    return { mode: "javascript", pattern: await Bn(t, { wrapExpression: !!e }), meta: s2 };
  };
  var Ct2;
  var J2 = true;
  var dh = function(t) {
    J2 = !!t;
  };
  var mh = (t) => Ct2 = t;
  var f2 = class _f2 {
    /**
     * Create a pattern. As an end user, you will most likely not create a Pattern directly.
     *
     * @param {function} query - The function that maps a `State` to an array of `Hap`.
     * @noAutocomplete
     */
    constructor(e, n2 = void 0) {
      __publicField(this, "polyJoin", function() {
        const e = this;
        return e.fmap((n2) => n2.extend(e._steps.div(n2._steps))).outerJoin();
      });
      this.query = e, this._Pattern = true, this._steps = n2;
    }
    get _steps() {
      return this.__steps;
    }
    set _steps(e) {
      this.__steps = e === void 0 ? void 0 : m(e);
    }
    setSteps(e) {
      return this._steps = e, this;
    }
    withSteps(e) {
      return J2 ? new _f2(this.query, this._steps === void 0 ? void 0 : e(this._steps)) : this;
    }
    get hasSteps() {
      return this._steps !== void 0;
    }
    //////////////////////////////////////////////////////////////////////
    // Haskell-style functor, applicative and monadic operations
    /**
     * Returns a new pattern, with the function applied to the value of
     * each hap. It has the alias `fmap`.
     * @synonyms fmap
     * @param {Function} func to to apply to the value
     * @returns Pattern
     * @example
     * "0 1 2".withValue(v => v + 10).log()
     */
    withValue(e) {
      const n2 = new _f2((s2) => this.query(s2).map((r) => r.withValue(e)));
      return n2._steps = this._steps, n2;
    }
    // runs func on query state
    withState(e) {
      return new _f2((n2) => this.query(e(n2)));
    }
    /**
     * see `withValue`
     * @noAutocomplete
     */
    fmap(e) {
      return this.withValue(e);
    }
    /**
     * Assumes 'this' is a pattern of functions, and given a function to
     * resolve wholes, applies a given pattern of values to that
     * pattern of functions.
     * @param {Function} whole_func
     * @param {Function} func
     * @noAutocomplete
     * @returns Pattern
     */
    appWhole(e, n2) {
      const s2 = this, r = function(o) {
        const i = s2.query(o), a2 = n2.query(o), u3 = function(p2, h) {
          const y3 = p2.part.intersection(h.part);
          if (y3 != null)
            return new S2(
              e(p2.whole, h.whole),
              y3,
              p2.value(h.value),
              h.combineContext(p2)
            );
        };
        return G(
          i.map((p2) => lt2(a2.map((h) => u3(p2, h))))
        );
      };
      return new _f2(r);
    }
    /**
     * When this method is called on a pattern of functions, it matches its haps
     * with those in the given pattern of values.  A new pattern is returned, with
     * each matching value applied to the corresponding function.
     *
     * In this `_appBoth` variant, where timespans of the function and value haps
     * are not the same but do intersect, the resulting hap has a timespan of the
     * intersection. This applies to both the part and the whole timespan.
     * @param {Pattern} pat_val
     * @noAutocomplete
     * @returns Pattern
     */
    appBoth(e) {
      const n2 = this, s2 = function(o, i) {
        if (!(o == null || i == null))
          return o.intersection_e(i);
      }, r = n2.appWhole(s2, e);
      return J2 && (r._steps = Y2(e._steps, n2._steps)), r;
    }
    /**
     * As with `appBoth`, but the `whole` timespan is not the intersection,
     * but the timespan from the function of patterns that this method is called
     * on. In practice, this means that the pattern structure, including onsets,
     * are preserved from the pattern of functions (often referred to as the left
     * hand or inner pattern).
     * @param {Pattern} pat_val
     * @noAutocomplete
     * @returns Pattern
     */
    appLeft(e) {
      const n2 = this, s2 = function(o) {
        const i = [];
        for (const a2 of n2.query(o)) {
          const u3 = e.query(o.setSpan(a2.wholeOrPart()));
          for (const p2 of u3) {
            const h = a2.whole, y3 = a2.part.intersection(p2.part);
            if (y3) {
              const g3 = a2.value(p2.value), v2 = p2.combineContext(a2), _5 = new S2(h, y3, g3, v2);
              i.push(_5);
            }
          }
        }
        return i;
      }, r = new _f2(s2);
      return r._steps = this._steps, r;
    }
    /**
     * As with `appLeft`, but `whole` timespans are instead taken from the
     * pattern of values, i.e. structure is preserved from the right hand/outer
     * pattern.
     * @param {Pattern} pat_val
     * @noAutocomplete
     * @returns Pattern
     */
    appRight(e) {
      const n2 = this, s2 = function(o) {
        const i = [];
        for (const a2 of e.query(o)) {
          const u3 = n2.query(o.setSpan(a2.wholeOrPart()));
          for (const p2 of u3) {
            const h = a2.whole, y3 = p2.part.intersection(a2.part);
            if (y3) {
              const g3 = p2.value(a2.value), v2 = a2.combineContext(p2), _5 = new S2(h, y3, g3, v2);
              i.push(_5);
            }
          }
        }
        return i;
      }, r = new _f2(s2);
      return r._steps = e._steps, r;
    }
    bindWhole(e, n2) {
      const s2 = this, r = function(o) {
        const i = function(u3, p2) {
          return new S2(
            e(u3.whole, p2.whole),
            p2.part,
            p2.value,
            Object.assign({}, u3.context, p2.context, {
              locations: (u3.context.locations || []).concat(p2.context.locations || [])
            })
          );
        }, a2 = function(u3) {
          return n2(u3.value).query(o.setSpan(u3.part)).map((p2) => i(u3, p2));
        };
        return G(s2.query(o).map((u3) => a2(u3)));
      };
      return new _f2(r);
    }
    bind(e) {
      const n2 = function(s2, r) {
        if (!(s2 == null || r == null))
          return s2.intersection_e(r);
      };
      return this.bindWhole(n2, e);
    }
    join() {
      return this.bind(ot2);
    }
    outerBind(e) {
      return this.bindWhole((n2) => n2, e).setSteps(this._steps);
    }
    outerJoin() {
      return this.outerBind(ot2);
    }
    innerBind(e) {
      return this.bindWhole((n2, s2) => s2, e);
    }
    innerJoin() {
      return this.innerBind(ot2);
    }
    // Flatterns patterns of patterns, by retriggering/resetting inner patterns at onsets of outer pattern haps
    resetJoin(e = false) {
      const n2 = this;
      return new _f2((s2) => n2.discreteOnly().query(s2).map((r) => r.value.late(e ? r.whole.begin : r.whole.begin.cyclePos()).query(s2).map(
        (o) => new S2(
          // Supports continuous haps in the inner pattern
          o.whole ? o.whole.intersection(r.whole) : void 0,
          o.part.intersection(r.part),
          o.value
        ).setContext(r.combineContext(o))
      ).filter((o) => o.part)).flat());
    }
    restartJoin() {
      return this.resetJoin(true);
    }
    // Like the other joins above, joins a pattern of patterns of values, into a flatter
    // pattern of values. In this case it takes whole cycles of the inner pattern to fit each event
    // in the outer pattern.
    squeezeJoin() {
      const e = this;
      function n2(s2) {
        const r = e.discreteOnly().query(s2);
        function o(a2) {
          const p2 = a2.value._focusSpan(a2.wholeOrPart()).query(s2.setSpan(a2.part));
          function h(y3, g3) {
            let v2;
            if (g3.whole && y3.whole && (v2 = g3.whole.intersection(y3.whole), !v2))
              return;
            const _5 = g3.part.intersection(y3.part);
            if (!_5)
              return;
            const O2 = g3.combineContext(y3);
            return new S2(v2, _5, g3.value, O2);
          }
          return p2.map((y3) => h(a2, y3));
        }
        return G(r.map(o)).filter((a2) => a2);
      }
      return new _f2(n2);
    }
    squeezeBind(e) {
      return this.fmap(e).squeezeJoin();
    }
    polyBind(e) {
      return this.fmap(e).polyJoin();
    }
    //////////////////////////////////////////////////////////////////////
    // Utility methods mainly for internal use
    /**
     * Query haps inside the given time span.
     *
     * @param {Fraction | number} begin from time
     * @param {Fraction | number} end to time
     * @returns Hap[]
     * @example
     * const pattern = sequence('a', ['b', 'c'])
     * const haps = pattern.queryArc(0, 1)
     * console.log(haps)
     * silence
     * @noAutocomplete
     */
    queryArc(e, n2, s2 = {}) {
      try {
        return this.query(new ut2(new B2(e, n2), s2));
      } catch (r) {
        return zt2(r, "query"), [];
      }
    }
    /**
     * Returns a new pattern, with queries split at cycle boundaries. This makes
     * some calculations easier to express, as all haps are then constrained to
     * happen within a cycle.
     * @returns Pattern
     * @noAutocomplete
     */
    splitQueries() {
      const e = this, n2 = (s2) => G(s2.span.spanCycles.map((r) => e.query(s2.setSpan(r))));
      return new _f2(n2);
    }
    /**
     * Returns a new pattern, where the given function is applied to the query
     * timespan before passing it to the original pattern.
     * @param {Function} func the function to apply
     * @returns Pattern
     * @noAutocomplete
     */
    withQuerySpan(e) {
      return new _f2((n2) => this.query(n2.withSpan(e)));
    }
    withQuerySpanMaybe(e) {
      const n2 = this;
      return new _f2((s2) => {
        const r = s2.withSpan(e);
        return r.span ? n2.query(r) : [];
      });
    }
    /**
     * As with `withQuerySpan`, but the function is applied to both the
     * begin and end time of the query timespan.
     * @param {Function} func the function to apply
     * @returns Pattern
     * @noAutocomplete
     */
    withQueryTime(e) {
      return new _f2((n2) => this.query(n2.withSpan((s2) => s2.withTime(e))));
    }
    /**
     * Similar to `withQuerySpan`, but the function is applied to the timespans
     * of all haps returned by pattern queries (both `part` timespans, and where
     * present, `whole` timespans).
     * @param {Function} func
     * @returns Pattern
     * @noAutocomplete
     */
    withHapSpan(e) {
      return new _f2((n2) => this.query(n2).map((s2) => s2.withSpan(e)));
    }
    /**
     * As with `withHapSpan`, but the function is applied to both the
     * begin and end time of the hap timespans.
     * @param {Function} func the function to apply
     * @returns Pattern
     * @noAutocomplete
     */
    withHapTime(e) {
      return this.withHapSpan((n2) => n2.withTime(e));
    }
    /**
     * Returns a new pattern with the given function applied to the list of haps returned by every query.
     * @param {Function} func
     * @returns Pattern
     * @noAutocomplete
     */
    withHaps(e) {
      const n2 = new _f2((s2) => e(this.query(s2), s2));
      return n2._steps = this._steps, n2;
    }
    /**
     * As with `withHaps`, but applies the function to every hap, rather than every list of haps.
     * @param {Function} func
     * @returns Pattern
     * @noAutocomplete
     */
    withHap(e) {
      return this.withHaps((n2) => n2.map(e));
    }
    /**
     * Returns a new pattern with the context field set to every hap set to the given value.
     * @param {*} context
     * @returns Pattern
     * @noAutocomplete
     */
    setContext(e) {
      return this.withHap((n2) => n2.setContext(e));
    }
    /**
     * Returns a new pattern with the given function applied to the context field of every hap.
     * @param {Function} func
     * @returns Pattern
     * @noAutocomplete
     */
    withContext(e) {
      const n2 = this.withHap((s2) => s2.setContext(e(s2.context)));
      return this.__pure !== void 0 && (n2.__pure = this.__pure, n2.__pure_loc = this.__pure_loc), n2;
    }
    /**
     * Returns a new pattern with the context field of every hap set to an empty object.
     * @returns Pattern
     * @noAutocomplete
     */
    stripContext() {
      return this.withHap((e) => e.setContext({}));
    }
    /**
     * Returns a new pattern with the given location information added to the
     * context of every hap.
     * @param {Number} start start offset
     * @param {Number} end end offset
     * @returns Pattern
     * @noAutocomplete
     */
    withLoc(e, n2) {
      const s2 = {
        start: e,
        end: n2
      }, r = this.withContext((o) => {
        const i = (o.locations || []).concat([s2]);
        return { ...o, locations: i };
      });
      return this.__pure && (r.__pure = this.__pure, r.__pure_loc = s2), r;
    }
    /**
     * Returns a new Pattern, which only returns haps that meet the given test.
     * @param {Function} hap_test - a function which returns false for haps to be removed from the pattern
     * @returns Pattern
     * @example
     * s("bd*8").velocity(rand).filterHaps((h) => (h.whole.begin % 1) < h.value.velocity)
     */
    filterHaps(e) {
      return new _f2((n2) => this.query(n2).filter(e));
    }
    /**
     * As with `filterHaps`, but the function is applied to values
     * inside haps.
     * @param {Function} value_test
     * @returns Pattern
     * @example
     * const drums = s("bd sd bd sd")
     * kick: drums.filterValues((v) => v.s === 'bd').duck(2)
     * snare: drums.filterValues((v) => v.s === 'sd')
     * bass: s("saw!4").note("G#1").lpf(80).lpenv(4).orbit(2)
     */
    filterValues(e) {
      return new _f2((n2) => this.query(n2).filter((s2) => e(s2.value))).setSteps(this._steps);
    }
    /**
     * Returns a new pattern, with haps containing undefined values removed from
     * query results.
     * @returns Pattern
     * @noAutocomplete
     */
    removeUndefineds() {
      return this.filterValues((e) => e != null);
    }
    /**
     * Returns a new pattern, with all haps without onsets filtered out. A hap
     * with an onset is one with a `whole` timespan that begins at the same time
     * as its `part` timespan.
     * @returns Pattern
     * @noAutocomplete
     */
    onsetsOnly() {
      return this.filterHaps((e) => e.hasOnset());
    }
    /**
     * Returns a new pattern, with 'continuous' haps (those without 'whole'
     * timespans) removed from query results.
     * @returns Pattern
     * @noAutocomplete
     */
    discreteOnly() {
      return this.filterHaps((e) => e.whole);
    }
    /**
     * Combines adjacent haps with the same value and whole.  Only
     * intended for use in tests.
     * @noAutocomplete
     */
    defragmentHaps() {
      return this.discreteOnly().withHaps((n2) => {
        const s2 = [];
        for (var r = 0; r < n2.length; ++r) {
          for (var o = true, i = n2[r]; o; ) {
            const p2 = JSON.stringify(n2[r].value);
            for (var a2 = false, u3 = r + 1; u3 < n2.length; u3++) {
              const h = n2[u3];
              if (i.whole.equals(h.whole)) {
                if (i.part.begin.eq(h.part.end)) {
                  if (p2 === JSON.stringify(h.value)) {
                    i = new S2(i.whole, new B2(h.part.begin, i.part.end), i.value), n2.splice(u3, 1), a2 = true;
                    break;
                  }
                } else if (h.part.begin.eq(i.part.end) && p2 == JSON.stringify(h.value)) {
                  i = new S2(i.whole, new B2(i.part.begin, h.part.end), i.value), n2.splice(u3, 1), a2 = true;
                  break;
                }
              }
            }
            o = a2;
          }
          s2.push(i);
        }
        return s2;
      });
    }
    /**
     * Queries the pattern for the first cycle, returning Haps. Mainly of use when
     * debugging a pattern.
     * @param {Boolean} with_context - set to true, otherwise the context field
     * will be stripped from the resulting haps.
     * @returns [Hap]
     * @noAutocomplete
     */
    firstCycle(e = false) {
      var n2 = this;
      return e || (n2 = n2.stripContext()), n2.query(new ut2(new B2(m(0), m(1))));
    }
    /**
     * Accessor for a list of values returned by querying the first cycle.
     * @noAutocomplete
     */
    get firstCycleValues() {
      return this.firstCycle().map((e) => e.value);
    }
    /**
     * More human-readable version of the `firstCycleValues` accessor.
     * @noAutocomplete
     */
    get showFirstCycle() {
      return this.firstCycle().map(
        (e) => `${e.value}: ${e.whole.begin.toFraction()} - ${e.whole.end.toFraction()}`
      );
    }
    /**
     * Returns a new pattern, which returns haps sorted in temporal order. Mainly
     * of use when comparing two patterns for equality, in tests.
     * @returns Pattern
     * @noAutocomplete
     */
    sortHapsByPart() {
      return this.withHaps(
        (e) => e.sort(
          (n2, s2) => n2.part.begin.sub(s2.part.begin).or(n2.part.end.sub(s2.part.end)).or(n2.whole.begin.sub(s2.whole.begin).or(n2.whole.end.sub(s2.whole.end)))
        )
      );
    }
    asNumber() {
      return this.fmap(ce2);
    }
    //////////////////////////////////////////////////////////////////////
    // Operators - see 'make composers' later..
    _opIn(e, n2) {
      return this.fmap(n2).appLeft(d(e));
    }
    _opOut(e, n2) {
      return this.fmap(n2).appRight(d(e));
    }
    _opMix(e, n2) {
      return this.fmap(n2).appBoth(d(e));
    }
    _opSqueeze(e, n2) {
      const s2 = d(e);
      return this.fmap((r) => s2.fmap((o) => n2(r)(o))).squeezeJoin();
    }
    _opSqueezeOut(e, n2) {
      const s2 = this;
      return d(e).fmap((o) => s2.fmap((i) => n2(i)(o))).squeezeJoin();
    }
    _opReset(e, n2) {
      return d(e).fmap((r) => this.fmap((o) => n2(o)(r))).resetJoin();
    }
    _opRestart(e, n2) {
      return d(e).fmap((r) => this.fmap((o) => n2(o)(r))).restartJoin();
    }
    _opPoly(e, n2) {
      const s2 = d(e);
      return this.fmap((r) => s2.fmap((o) => n2(o)(r))).polyJoin();
    }
    //////////////////////////////////////////////////////////////////////
    // End-user methods.
    // Those beginning with an underscore (_) are 'patternified',
    // i.e. versions are created without the underscore, that are
    // magically transformed to accept patterns for all their arguments.
    //////////////////////////////////////////////////////////////////////
    // Methods without corresponding toplevel functions
    /**
     * Layers the result of the given function(s). Like `superimpose`, but without the original pattern:
     * @name layer
     * @memberof Pattern
     * @synonyms apply
     * @returns Pattern
     * @example
     * "<0 2 4 6 ~ 4 ~ 2 0!3 ~!5>*8"
     *   .layer(x=>x.add("0,2"))
     *   .scale('C minor').note()
     */
    layer(...e) {
      return z(...e.map((n2) => n2(this)));
    }
    /**
     * Superimposes the result of the given function(s) on top of the original pattern:
     * @name superimpose
     * @memberof Pattern
     * @returns Pattern
     * @example
     * "<0 2 4 6 ~ 4 ~ 2 0!3 ~!5>*8"
     *   .superimpose(x=>x.add(2))
     *   .scale('C minor').note()
     */
    superimpose(...e) {
      return this.stack(...e.map((n2) => n2(this)));
    }
    //////////////////////////////////////////////////////////////////////
    // Multi-pattern functions
    stack(...e) {
      return z(this, ...e);
    }
    sequence(...e) {
      return Q2(this, ...e);
    }
    seq(...e) {
      return Q2(this, ...e);
    }
    cat(...e) {
      return mt2(this, ...e);
    }
    fastcat(...e) {
      return N2(this, ...e);
    }
    slowcat(...e) {
      return Z2(this, ...e);
    }
    //////////////////////////////////////////////////////////////////////
    // Context methods - ones that deal with metadata
    onTrigger(e, n2 = true) {
      return this.withHap(
        (s2) => s2.setContext({
          ...s2.context,
          onTrigger: (...r) => {
            s2.context.onTrigger?.(...r), e(...r);
          },
          // if dominantTrigger is set to true, the default output (webaudio) will be disabled
          // when using multiple triggers, you cannot flip this flag to false again!
          // example: x.csound('CooLSynth').log() as well as x.log().csound('CooLSynth') should work the same
          dominantTrigger: s2.context.dominantTrigger || n2
        })
      );
    }
    /**
     * Writes the content of the current event to the console (visible in the side menu).
     * @name log
     * @memberof Pattern
     * @example
     * s("bd sd").log()
     */
    log(e = (s2) => `[hap] ${s2.showWhole(true)}`, n2 = (s2) => ({ hap: s2 })) {
      return this.onTrigger((...s2) => {
        E2(e(...s2), void 0, n2(...s2));
      }, false);
    }
    /**
     * A simplified version of `log` which writes all "values" (various configurable parameters)
     * within the event to the console (visible in the side menu).
     * @name logValues
     * @memberof Pattern
     * @example
     * s("bd sd").gain("0.25 0.5 1").n("2 1 0").logValues()
     */
    logValues(e = (n2) => `[hap] ${ae(n2, true)}`) {
      return this.log((n2) => e(n2.value));
    }
    //////////////////////////////////////////////////////////////////////
    // Visualisation
    drawLine() {
      return console.log(Cn(this)), this;
    }
    //////////////////////////////////////////////////////////////////////
    // methods relating to breaking patterns into subcycles
    // Breaks a pattern into a pattern of patterns, according to the structure of the given binary pattern.
    unjoin(e, n2 = ot2) {
      return e.withHap(
        (s2) => s2.withValue((r) => r ? n2(this.ribbon(s2.whole.begin, s2.whole.duration)) : this)
      );
    }
    /**
     * Breaks a pattern into pieces according to the structure of a given pattern.
     * True values in the given pattern cause the corresponding subcycle of the
     * source pattern to be looped, and for an (optional) given function to be
     * applied. False values result in the corresponding part of the source pattern
     * to be played unchanged.
     * @name into
     * @memberof Pattern
     * @example
     * sound("bd sd ht lt").into("1 0", hurry(2))
     */
    into(e, n2) {
      return this.unjoin(e, n2).innerJoin();
    }
  };
  function zn(t, e) {
    let n2 = [];
    return e.forEach((s2) => {
      const r = n2.findIndex(([o]) => t(s2, o));
      r === -1 ? n2.push([s2]) : n2[r].push(s2);
    }), n2;
  }
  var Mn = (t, e) => t.spanEquals(e);
  f2.prototype.collect = function() {
    return this.withHaps(
      (t) => zn(Mn, t).map((e) => new S2(e[0].whole, e[0].part, e, {}))
    );
  };
  var yh = l("arpWith", (t, e) => e.collect().fmap((n2) => d(t(n2))).innerJoin().withHap((n2) => new S2(n2.whole, n2.part, n2.value.value, n2.combineContext(n2.value))));
  var wh = l(
    "arp",
    (t, e) => e.arpWith((n2) => d(t).fmap((s2) => n2[s2 % n2.length])),
    false
  );
  function dt2(t) {
    return !Array.isArray(t) && typeof t == "object" && !An(t);
  }
  function Pn(t, e, n2) {
    return dt2(t) || dt2(e) ? (dt2(t) || (t = { value: t }), dt2(e) || (e = { value: e }), Tn(t, e, n2)) : n2(t, e);
  }
  (function() {
    const t = {
      set: [(n2, s2) => s2],
      keep: [(n2) => n2],
      keepif: [(n2, s2) => s2 ? n2 : void 0],
      // numerical functions
      /**
       *
       * Assumes a pattern of numbers. Adds the given number to each item in the pattern.
       * @name add
       * @memberof Pattern
       * @example
       * // Here, the triad 0, 2, 4 is shifted by different amounts
       * n("0 2 4".add("<0 3 4 0>")).scale("C:major")
       * // Without add, the equivalent would be:
       * // n("<[0 2 4] [3 5 7] [4 6 8] [0 2 4]>").scale("C:major")
       * @example
       * // You can also use add with notes:
       * note("c3 e3 g3".add("<0 5 7 0>"))
       * // Behind the scenes, the notes are converted to midi numbers:
       * // note("48 52 55".add("<0 5 7 0>"))
       */
      add: [L2((n2, s2) => n2 + s2)],
      // support string concatenation
      /**
       *
       * Like add, but the given numbers are subtracted.
       * @name sub
       * @memberof Pattern
       * @example
       * n("0 2 4".sub("<0 1 2 3>")).scale("C4:minor")
       * // See add for more information.
       */
      sub: [L2((n2, s2) => n2 - s2)],
      /**
       *
       * Multiplies each number by the given factor.
       * @name mul
       * @memberof Pattern
       * @example
       * "<1 1.5 [1.66, <2 2.33>]>*4".mul(150).freq()
       */
      mul: [L2((n2, s2) => n2 * s2)],
      /**
       *
       * Divides each number by the given factor.
       * @name div
       * @memberof Pattern
       */
      div: [L2((n2, s2) => n2 / s2)],
      mod: [L2(bt2)],
      pow: [L2(Math.pow)],
      log2: [L2(Math.log2)],
      band: [L2((n2, s2) => n2 & s2)],
      bor: [L2((n2, s2) => n2 | s2)],
      bxor: [L2((n2, s2) => n2 ^ s2)],
      blshift: [L2((n2, s2) => n2 << s2)],
      brshift: [L2((n2, s2) => n2 >> s2)],
      // TODO - force numerical comparison if both look like numbers?
      lt: [(n2, s2) => n2 < s2],
      gt: [(n2, s2) => n2 > s2],
      lte: [(n2, s2) => n2 <= s2],
      gte: [(n2, s2) => n2 >= s2],
      eq: [(n2, s2) => n2 == s2],
      eqt: [(n2, s2) => n2 === s2],
      ne: [(n2, s2) => n2 != s2],
      net: [(n2, s2) => n2 !== s2],
      and: [(n2, s2) => n2 && s2],
      or: [(n2, s2) => n2 || s2],
      //  bitwise ops
      func: [(n2, s2) => s2(n2)]
    }, e = ["In", "Out", "Mix", "Squeeze", "SqueezeOut", "Reset", "Restart", "Poly"];
    for (const [n2, [s2, r]] of Object.entries(t)) {
      f2.prototype["_" + n2] = function(o) {
        return this.fmap((i) => s2(i, o));
      }, Object.defineProperty(f2.prototype, n2, {
        // a getter that returns a function, so 'pat' can be
        // accessed by closures that are methods of that function..
        get: function() {
          const o = this, i = (...a2) => o[n2].in(...a2);
          for (const a2 of e)
            i[a2.toLowerCase()] = function(...u3) {
              var p2 = o;
              u3 = Q2(u3), r && (p2 = r(p2), u3 = r(u3));
              var h;
              return n2 === "keepif" ? (h = p2["_op" + a2](u3, (y3) => (g3) => s2(y3, g3)), h = h.removeUndefineds()) : h = p2["_op" + a2](u3, (y3) => (g3) => Pn(y3, g3, s2)), h;
            };
          return i.squeezein = i.squeeze, i;
        }
      });
      for (const o of e)
        f2.prototype[o.toLowerCase()] = function(...i) {
          return this.set[o.toLowerCase()](i);
        };
    }
    f2.prototype.struct = function(...n2) {
      return this.keepif.out(...n2);
    }, f2.prototype.structAll = function(...n2) {
      return this.keep.out(...n2);
    }, f2.prototype.mask = function(...n2) {
      return this.keepif.in(...n2);
    }, f2.prototype.maskAll = function(...n2) {
      return this.keep.in(...n2);
    }, f2.prototype.reset = function(...n2) {
      return this.keepif.reset(...n2);
    }, f2.prototype.resetAll = function(...n2) {
      return this.keep.reset(...n2);
    }, f2.prototype.restart = function(...n2) {
      return this.keepif.restart(...n2);
    }, f2.prototype.restartAll = function(...n2) {
      return this.keep.restart(...n2);
    };
  })();
  var gh = z;
  var bh = z;
  var _h = $t2;
  var pt2 = (t) => new f2(() => [], t);
  var q2 = pt2(1);
  var R = pt2(0);
  function C2(t) {
    function e(s2) {
      return s2.span.spanCycles.map((r) => new S2(m(r.begin).wholeCycle(), r, t));
    }
    const n2 = new f2(e, 1);
    return n2.__pure = t, n2;
  }
  function pe2(t) {
    return t instanceof f2 || t?._Pattern;
  }
  function d(t) {
    return pe2(t) ? t : Ct2 && typeof t == "string" ? Ct2(t) : C2(t);
  }
  function En(t) {
    let e = C2([]);
    for (const n2 of t)
      e = e.bind((s2) => n2.fmap((r) => s2.concat([r])));
    return e;
  }
  function z(...t) {
    t = t.map((s2) => Array.isArray(s2) ? Q2(...s2) : d(s2));
    const e = (s2) => G(t.map((r) => r.query(s2))), n2 = new f2(e);
    return J2 && (n2._steps = Y2(...t.map((s2) => s2._steps))), n2;
  }
  function Et2(t, e) {
    if (e = e.map((o) => Array.isArray(o) ? Q2(...o) : d(o)), e.length === 0)
      return q2;
    if (e.length === 1)
      return e[0];
    const [n2, ...s2] = e.map((o) => o._steps), r = J2 ? n2.maximum(...s2) : void 0;
    return z(...t(r, e));
  }
  function jn(...t) {
    return Et2(
      (e, n2) => n2.map((s2) => s2._steps.eq(e) ? s2 : $2(s2, pt2(e.sub(s2._steps)))),
      t
    );
  }
  function Jn(...t) {
    return Et2(
      (e, n2) => n2.map((s2) => s2._steps.eq(e) ? s2 : $2(pt2(e.sub(s2._steps)), s2)),
      t
    );
  }
  function $n(...t) {
    return Et2(
      (e, n2) => n2.map((s2) => {
        if (s2._steps.eq(e))
          return s2;
        const r = pt2(e.sub(s2._steps).div(2));
        return $2(r, s2, r);
      }),
      t
    );
  }
  function vh(t, ...e) {
    const [n2, ...s2] = e.map((i) => i._steps), r = n2.maximum(...s2), o = {
      centre: $n,
      left: jn,
      right: Jn,
      expand: z,
      repeat: (...i) => $t2(...i).steps(r)
    };
    return t.inhabit(o).fmap((i) => i(...e)).innerJoin().setSteps(r);
  }
  function Z2(...t) {
    if (t = t.map((s2) => Array.isArray(s2) ? N2(...s2) : d(s2)), t.length == 1)
      return t[0];
    const e = function(s2) {
      const r = s2.span, o = bt2(r.begin.sam(), t.length), i = t[o];
      if (!i)
        return [];
      const a2 = r.begin.floor().sub(r.begin.div(t.length).floor());
      return i.withHapTime((u3) => u3.add(a2)).query(s2.setSpan(r.withTime((u3) => u3.sub(a2))));
    }, n2 = J2 ? Y2(...t.map((s2) => s2._steps)) : void 0;
    return new f2(e).splitQueries().setSteps(n2);
  }
  function fe2(...t) {
    t = t.map(d);
    const e = function(n2) {
      const s2 = Math.floor(n2.span.begin) % t.length;
      return t[s2]?.query(n2) || [];
    };
    return new f2(e).splitQueries();
  }
  function mt2(...t) {
    return Z2(...t);
  }
  function kh(...t) {
    const e = t.reduce((n2, [s2]) => n2 + s2, 0);
    return t = t.map(([n2, s2]) => [n2, s2.fast(n2)]), $2(...t).slow(e);
  }
  function qh(...t) {
    let e = m(0);
    for (let n2 of t)
      n2.length == 2 && n2.unshift(e), e = n2[1];
    return z(
      ...t.map(
        ([n2, s2, r]) => C2(d(r)).compress(m(n2).div(e), m(s2).div(e))
      )
    ).slow(e).innerJoin();
  }
  function N2(...t) {
    let e = Z2(...t);
    return t.length > 1 && (e = e._fast(t.length), e._steps = t.length), t.length == 1 && t[0].__steps_source && (t._steps = t[0]._steps), e;
  }
  function Q2(...t) {
    return N2(...t);
  }
  function Nn(...t) {
    return N2(...t);
  }
  function xt2(t) {
    return Array.isArray(t) ? t.length == 0 ? [q2, 0] : t.length == 1 ? xt2(t[0]) : [N2(...t.map((e) => xt2(e)[0])), t.length] : [d(t), 1];
  }
  var Sh = w2((t, e) => d(e).mask(t));
  var Ah = w2((t, e) => d(e).struct(t));
  var Th = w2((t, e) => d(e).superimpose(...t));
  var Ch = w2((t, e) => d(e).withValue(t));
  var xh = w2((t, e) => d(e).bind(t));
  var Bh = w2((t, e) => d(e).innerBind(t));
  var Oh = w2((t, e) => d(e).outerBind(t));
  var zh = w2((t, e) => d(e).squeezeBind(t));
  var Mh = w2((t, e) => d(e).stepBind(t));
  var Ph = w2((t, e) => d(e).polyBind(t));
  var Eh = w2((t, e) => d(e).set(t));
  var jh = w2((t, e) => d(e).keep(t));
  var Jh = w2((t, e) => d(e).keepif(t));
  var $h = w2((t, e) => d(e).add(t));
  var Nh = w2((t, e) => d(e).sub(t));
  var Lh = w2((t, e) => d(e).mul(t));
  var Rh = w2((t, e) => d(e).div(t));
  var Wh = w2((t, e) => d(e).mod(t));
  var Fh = w2((t, e) => d(e).pow(t));
  var Ih = w2((t, e) => d(e).band(t));
  var Vh = w2((t, e) => d(e).bor(t));
  var Hh = w2((t, e) => d(e).bxor(t));
  var Dh = w2((t, e) => d(e).blshift(t));
  var Gh = w2((t, e) => d(e).brshift(t));
  var Qh = w2((t, e) => d(e).lt(t));
  var Uh = w2((t, e) => d(e).gt(t));
  var Xh = w2((t, e) => d(e).lte(t));
  var Kh = w2((t, e) => d(e).gte(t));
  var Yh = w2((t, e) => d(e).eq(t));
  var Zh = w2((t, e) => d(e).eqt(t));
  var td = w2((t, e) => d(e).ne(t));
  var ed = w2((t, e) => d(e).net(t));
  var nd = w2((t, e) => d(e).and(t));
  var sd = w2((t, e) => d(e).or(t));
  var rd = w2((t, e) => d(e).func(t));
  function l(t, e, n2 = true, s2 = false, r = (o) => o.innerJoin()) {
    if (Array.isArray(t)) {
      const u3 = {};
      for (const p2 of t)
        u3[p2] = l(p2, e, n2, s2, r);
      return u3;
    }
    const o = e.length;
    var i;
    n2 ? i = function(...u3) {
      u3 = u3.map(d);
      const p2 = u3[u3.length - 1];
      let h;
      if (o === 1)
        h = e(p2);
      else {
        const y3 = u3.slice(0, -1);
        if (y3.every((g3) => g3.__pure != null)) {
          const g3 = y3.map((_5) => _5.__pure), v2 = y3.filter((_5) => _5.__pure_loc).map((_5) => _5.__pure_loc);
          h = e(...g3, p2), h = h.withContext((_5) => {
            const O2 = (_5.locations || []).concat(v2);
            return { ..._5, locations: O2 };
          });
        } else {
          const [g3, ...v2] = y3;
          let _5 = (...O2) => e(...O2, p2);
          _5 = w2(_5, null, o - 1), h = r(v2.reduce((O2, A4) => O2.appLeft(A4), g3.fmap(_5)));
        }
      }
      return s2 && (h._steps = p2._steps), h;
    } : i = function(...u3) {
      u3 = u3.map(d);
      const p2 = e(...u3);
      return s2 && (p2._steps = u3[u3.length - 1]._steps), p2;
    }, f2.prototype[t] = function(...u3) {
      if (o === 2 && u3.length !== 1)
        u3 = [Q2(...u3)];
      else if (o !== u3.length + 1)
        throw new Error(`.${t}() expects ${o - 1} inputs but got ${u3.length}.`);
      return u3 = u3.map(d), i(...u3, this);
    }, o > 1 && (f2.prototype["_" + t] = function(...u3) {
      const p2 = e(...u3, this);
      return s2 && p2.setSteps(this._steps), p2;
    });
    const a2 = w2(i, null, o);
    return le[t] = a2, a2;
  }
  function et2(t, e, n2 = true, s2 = false, r = (o) => o.stepJoin()) {
    return l(t, e, n2, s2, r);
  }
  var od = l("round", function(t) {
    return t.asNumber().fmap((e) => Math.round(e));
  });
  var cd = l("floor", function(t) {
    return t.asNumber().fmap((e) => Math.floor(e));
  });
  var id = l("ceil", function(t) {
    return t.asNumber().fmap((e) => Math.ceil(e));
  });
  var ud = l("toBipolar", function(t) {
    return t.fmap((e) => e * 2 - 1);
  });
  var ad = l("fromBipolar", function(t) {
    return t.fmap((e) => (e + 1) / 2);
  });
  var ld = l("range", function(t, e, n2) {
    return n2.mul(e - t).add(t);
  });
  var pd = l("rangex", function(t, e, n2) {
    return n2._range(Math.log(t), Math.log(e)).fmap(Math.exp);
  });
  var fd = l("range2", function(t, e, n2) {
    return n2.fromBipolar()._range(t, e);
  });
  var hd = l(
    "ratio",
    (t) => t.fmap((e) => Array.isArray(e) ? e.slice(1).reduce((n2, s2) => n2 / s2, e[0]) : e)
  );
  var dd = l("compress", function(t, e, n2) {
    return t = m(t), e = m(e), t.gt(e) || t.gt(1) || e.gt(1) || t.lt(0) || e.lt(0) ? q2 : n2._fastGap(m(1).div(e.sub(t)))._late(t);
  });
  var { compressSpan: md, compressspan: yd } = l(["compressSpan", "compressspan"], function(t, e) {
    return e._compress(t.begin, t.end);
  });
  var { fastGap: wd, fastgap: gd } = l(["fastGap", "fastgap"], function(t, e) {
    const n2 = function(r) {
      const o = r.begin.sam(), i = r.begin.sub(o).mul(t).min(1), a2 = r.end.sub(o).mul(t).min(1);
      if (!(i >= 1))
        return new B2(o.add(i), o.add(a2));
    }, s2 = function(r) {
      const o = r.part.begin, i = r.part.end, a2 = o.sam(), u3 = o.sub(a2).div(t).min(1), p2 = i.sub(a2).div(t).min(1), h = new B2(a2.add(u3), a2.add(p2)), y3 = r.whole ? new B2(
        h.begin.sub(o.sub(r.whole.begin).div(t)),
        h.end.add(r.whole.end.sub(i).div(t))
      ) : void 0;
      return new S2(y3, h, r.value, r.context);
    };
    return e.withQuerySpanMaybe(n2).withHap(s2).splitQueries();
  });
  var bd = l("focus", function(t, e, n2) {
    return t = m(t), e = m(e), n2._early(t.sam())._fast(m(1).div(e.sub(t)))._late(t);
  });
  var { focusSpan: _d, focusspan: vd } = l(["focusSpan", "focusspan"], function(t, e) {
    return e._focus(t.begin, t.end);
  });
  var kd = l("ply", function(t, e) {
    const n2 = e.fmap((s2) => C2(s2)._fast(t)).squeezeJoin();
    return J2 && (n2._steps = m(t).mulmaybe(e._steps)), n2;
  });
  var { fast: qd, density: Sd } = l(
    ["fast", "density"],
    function(t, e) {
      return t === 0 ? q2 : (t = m(t), e.withQueryTime((s2) => s2.mul(t)).withHapTime((s2) => s2.div(t)).setSteps(e._steps));
    },
    true,
    true
  );
  var Ad = l("hurry", function(t, e) {
    return e._fast(t).mul(C2({ speed: t }));
  });
  var { slow: Td, sparsity: Cd } = l(["slow", "sparsity"], function(t, e) {
    return t === 0 ? q2 : e._fast(m(1).div(t));
  });
  var xd = l("inside", function(t, e, n2) {
    return e(n2._slow(t))._fast(t);
  });
  var Bd = l("outside", function(t, e, n2) {
    return e(n2._fast(t))._slow(t);
  });
  var Od = l("lastOf", function(t, e, n2) {
    const s2 = Array(t - 1).fill(n2);
    return s2.push(e(n2)), fe2(...s2);
  });
  var { firstOf: zd, every: Md } = l(["firstOf", "every"], function(t, e, n2) {
    const s2 = Array(t - 1).fill(n2);
    return s2.unshift(e(n2)), fe2(...s2);
  });
  var Pd = l("apply", function(t, e) {
    return t(e);
  });
  var Ed = l("cpm", function(t, e) {
    return e._fast(t / 60 / 1);
  });
  var jd = l(
    "early",
    function(t, e) {
      return t = m(t), e.withQueryTime((n2) => n2.add(t)).withHapTime((n2) => n2.sub(t));
    },
    true,
    true
  );
  var Ln = l(
    "late",
    function(t, e) {
      return t = m(t), e._early(m(0).sub(t));
    },
    true,
    true
  );
  var Jd = l("zoom", function(t, e, n2) {
    if (e = m(e), t = m(t), t.gte(e))
      return R;
    const s2 = e.sub(t), r = J2 ? n2._steps?.mulmaybe(s2) : void 0;
    return n2.withQuerySpan((o) => o.withCycle((i) => i.mul(s2).add(t))).withHapSpan((o) => o.withCycle((i) => i.sub(t).div(s2))).splitQueries().setSteps(r);
  });
  var { zoomArc: $d, zoomarc: Nd } = l(["zoomArc", "zoomarc"], function(t, e) {
    return e.zoom(t.begin, t.end);
  });
  var Ld = l(
    "bite",
    (t, e, n2) => e.fmap((s2) => (r) => {
      const o = m(s2).div(r).mod(1), i = o.add(m(1).div(r));
      return n2.zoom(o, i);
    }).appLeft(t).squeezeJoin(),
    false
  );
  var Rd = l(
    "linger",
    function(t, e) {
      return t == 0 ? q2 : t < 0 ? e._zoom(t.add(1), 1)._slow(t) : e._zoom(0, t)._slow(t);
    },
    true,
    true
  );
  var { segment: Wd, seg: Fd } = l(["segment", "seg"], function(t, e) {
    return e.struct(C2(true)._fast(t)).setSteps(t);
  });
  var Id = l("swingBy", (t, e, n2) => n2.inside(e, Ln(Nn(0, t / 2))));
  var Vd = l("swing", (t, e) => e.swingBy(1 / 3, t));
  var { invert: Hd, inv: Dd } = l(
    ["invert", "inv"],
    function(t) {
      return t.fmap((e) => !e);
    },
    true,
    true
  );
  var Gd = l("when", function(t, e, n2) {
    return t ? e(n2) : n2;
  });
  var Qd = l("off", function(t, e, n2) {
    return z(n2, e(n2.late(t)));
  });
  var Ud = l("brak", function(t) {
    return t.when(Z2(false, true), (e) => N2(e, q2)._late(0.25));
  });
  var Rn = l(
    "rev",
    function(t) {
      const e = function(n2) {
        const s2 = n2.span, r = s2.begin.sam(), o = s2.begin.nextSam(), i = function(u3) {
          const p2 = u3.withTime((y3) => r.add(o.sub(y3))), h = p2.begin;
          return p2.begin = p2.end, p2.end = h, p2;
        };
        return t.query(n2.setSpan(i(s2))).map((u3) => u3.withSpan(i));
      };
      return new f2(e).splitQueries();
    },
    false,
    true
  );
  var Xd = l("revv", function(t) {
    const e = (n2) => new B2(m(0).sub(n2.end), m(0).sub(n2.begin));
    return t.withQuerySpan(e).withHapSpan(e);
  });
  var Kd = l("pressBy", function(t, e) {
    return e.fmap((n2) => C2(n2).compress(t, 1)).squeezeJoin();
  });
  var Yd = l("press", function(t) {
    return t._pressBy(0.5);
  });
  f2.prototype.hush = function() {
    return q2;
  };
  var Zd = l(
    "palindrome",
    function(t) {
      return t.lastOf(2, Rn);
    },
    true,
    true
  );
  var { juxBy: tm, juxby: em } = l(["juxBy", "juxby"], function(t, e, n2) {
    t /= 2;
    const s2 = function(i, a2, u3) {
      return a2 in i ? i[a2] : u3;
    }, r = n2.withValue((i) => Object.assign({}, i, { pan: s2(i, "pan", 0.5) - t })), o = e(n2.withValue((i) => Object.assign({}, i, { pan: s2(i, "pan", 0.5) + t })));
    return z(r, o).setSteps(J2 ? Y2(r._steps, o._steps) : void 0);
  });
  var nm = l("jux", function(t, e) {
    return e._juxBy(1, t, e);
  });
  var { echoWith: sm, echowith: rm, stutWith: om, stutwith: cm } = l(
    ["echoWith", "echowith", "stutWith", "stutwith"],
    function(t, e, n2, s2) {
      return z(..._t2(0, t - 1).map((r) => n2(s2.late(m(e).mul(r)), r)));
    }
  );
  var im = l("echo", function(t, e, n2, s2) {
    return s2._echoWith(t, e, (r, o) => r.gain(Math.pow(n2, o)));
  });
  var um = l("stut", function(t, e, n2, s2) {
    return s2._echoWith(t, n2, (r, o) => r.gain(Math.pow(e, o)));
  });
  var Wn = l("applyN", function(t, e, n2) {
    let s2 = n2;
    for (let r = 0; r < t; r++)
      s2 = e(s2);
    return s2;
  });
  var am = l(["plyWith", "plywith"], function(t, e, n2) {
    const s2 = n2.fmap((r) => mt2(..._t2(0, t - 1).map((o) => Wn(o, e, r)))._fast(t)).squeezeJoin();
    return J2 && (s2._steps = m(t).mulmaybe(n2._steps)), s2;
  });
  var lm = l(["plyForEach", "plyforeach"], function(t, e, n2) {
    const s2 = n2.fmap((r) => mt2(mt2(C2(r), ..._t2(1, t - 1).map((o) => e(C2(r), o))))._fast(t)).squeezeJoin();
    return J2 && (s2._steps = m(t).mulmaybe(n2._steps)), s2;
  });
  var jt2 = function(t, e, n2 = false) {
    return t = m(t), Z2(
      ..._t2(0, t.sub(1)).map(
        (s2) => n2 ? e.late(m(s2).div(t)) : e.early(m(s2).div(t))
      )
    );
  };
  var pm = l(
    "iter",
    function(t, e) {
      return jt2(t, e, false);
    },
    true,
    true
  );
  var { iterBack: fm, iterback: hm } = l(
    ["iterBack", "iterback"],
    function(t, e) {
      return jt2(t, e, true);
    },
    true,
    true
  );
  var { repeatCycles: dm } = l(
    "repeatCycles",
    function(t, e) {
      return new f2(function(n2) {
        const s2 = n2.span.begin.sam(), r = s2.div(t).sam(), o = s2.sub(r);
        return n2 = n2.withSpan((i) => i.withTime((a2) => a2.sub(o))), e.query(n2).map((i) => i.withSpan((a2) => a2.withTime((u3) => u3.add(o))));
      }).splitQueries();
    },
    true,
    true
  );
  var Jt2 = function(t, e, n2, s2 = false, r = false) {
    const o = Array(t - 1).fill(false);
    o.unshift(true);
    const i = jt2(t, Q2(...o), !s2);
    return r || (n2 = n2.repeatCycles(t)), n2.when(i, e);
  };
  var { chunk: mm, slowchunk: ym, slowChunk: wm } = l(
    ["chunk", "slowchunk", "slowChunk"],
    function(t, e, n2) {
      return Jt2(t, e, n2, false, false);
    },
    true,
    true
  );
  var { chunkBack: gm, chunkback: bm } = l(
    ["chunkBack", "chunkback"],
    function(t, e, n2) {
      return Jt2(t, e, n2, true);
    },
    true,
    true
  );
  var { fastchunk: _m, fastChunk: vm } = l(
    ["fastchunk", "fastChunk"],
    function(t, e, n2) {
      return Jt2(t, e, n2, false, true);
    },
    true,
    true
  );
  var { chunkinto: km, chunkInto: qm } = l(["chunkinto", "chunkInto"], function(t, e, n2) {
    return n2.into(N2(true, ...Array(t - 1).fill(false))._iterback(t), e);
  });
  var { chunkbackinto: Sm, chunkBackInto: Am } = l(["chunkbackinto", "chunkBackInto"], function(t, e, n2) {
    return n2.into(
      N2(true, ...Array(t - 1).fill(false))._iter(t)._early(1),
      e
    );
  });
  var Tm = l(
    "bypass",
    function(t, e) {
      return t = !!parseInt(t), t ? q2 : e;
    },
    true,
    true
  );
  var { ribbon: Cm, rib: xm } = l(
    ["ribbon", "rib"],
    (t, e, n2) => n2.early(t).restart(C2(1).slow(e))
  );
  var Bm = l("hsla", (t, e, n2, s2, r) => r.color(`hsla(${t}turn,${e * 100}%,${n2 * 100}%,${s2})`));
  var Om = l("hsl", (t, e, n2, s2) => s2.color(`hsl(${t}turn,${e * 100}%,${n2 * 100}%)`));
  f2.prototype.tag = function(t) {
    return this.withContext((e) => ({ ...e, tags: (e.tags || []).concat([t]) }));
  };
  var zm = l("filter", (t, e) => e.withHaps((n2) => n2.filter(t)));
  var Mm = l("filterWhen", (t, e) => e.filter((n2) => t(n2.whole.begin)));
  var Pm = l(
    "within",
    (t, e, n2, s2) => z(
      n2(s2.filterWhen((r) => r.cyclePos() >= t && r.cyclePos() <= e)),
      s2.filterWhen((r) => r.cyclePos() < t || r.cyclePos() > e)
    )
  );
  f2.prototype.stepJoin = function() {
    const t = this, e = $2(...Yt2(Zt2(t.queryArc(0, 1))))._steps, n2 = function(s2) {
      const o = t.early(s2.span.begin.sam()).query(s2.setSpan(new B2(m(0), m(1))));
      return $2(...Yt2(Zt2(o))).query(s2);
    };
    return new f2(n2, e);
  };
  f2.prototype.stepBind = function(t) {
    return this.fmap(t).stepJoin();
  };
  function Yt2(t) {
    const e = t.filter((o, i) => i.hasSteps).reduce((o, i) => o.add(i), m(0)), n2 = lt2(t.map((o, i) => i._steps)).reduce(
      (o, i) => o.add(i),
      m(0)
    ), s2 = e.eq(0) ? void 0 : n2.div(e);
    function r(o, i) {
      return i._steps === void 0 ? [o.mulmaybe(s2), i] : [i._steps, i];
    }
    return t.map((o) => r(...o));
  }
  function Zt2(t) {
    const e = G(t.map((r) => [r.part.begin, r.part.end])), n2 = yn([m(0), m(1), ...e]);
    return un(n2).map((r) => [
      r[1].sub(r[0]),
      z(...Fn(new B2(...r), t).map((o) => o.value.withHap((i) => i.setContext(i.combineContext(o)))))
    ]);
  }
  function Fn(t, e) {
    return lt2(e.map((n2) => In(t, n2)));
  }
  function In(t, e) {
    const n2 = t.intersection(e.part);
    if (n2 != null)
      return new S2(e.whole, n2, e.value, e.context);
  }
  var Vn = l("pace", function(t, e) {
    return e._steps === void 0 ? e : e._steps.eq(m(0)) ? R : e._fast(m(t).div(e._steps)).setSteps(t);
  });
  function Hn(t, ...e) {
    const n2 = e.map((r) => xt2(r));
    if (n2.length == 0)
      return q2;
    t == 0 && (t = n2[0][1]);
    const s2 = [];
    for (const r of n2)
      r[1] != 0 && (t == r[1] ? s2.push(r[0]) : s2.push(r[0]._fast(m(t).div(m(r[1])))));
    return z(...s2);
  }
  function $t2(...t) {
    if (Array.isArray(t[0]))
      return Hn(0, ...t);
    if (t = t.filter((s2) => s2.hasSteps), t.length == 0)
      return q2;
    const e = Y2(...t.map((s2) => s2._steps));
    if (e.eq(m(0)))
      return R;
    const n2 = z(...t.map((s2) => s2.pace(e)));
    return n2._steps = e, n2;
  }
  function $2(...t) {
    if (t.length === 0)
      return R;
    const e = (i) => Array.isArray(i) ? i : [i._steps ?? 1, i];
    if (t = t.map(e), t.find((i) => i[0] === void 0)) {
      const i = t.map((u3) => u3[0]).filter((u3) => u3 !== void 0);
      if (i.length === 0)
        return N2(...t.map((u3) => u3[1]));
      if (i.length === t.length)
        return R;
      const a2 = i.reduce((u3, p2) => u3.add(p2), m(0)).div(i.length);
      for (let u3 of t)
        u3[0] === void 0 && (u3[0] = a2);
    }
    if (t.length == 1)
      return d(t[0][1]).withSteps((a2) => t[0][0]);
    const n2 = t.map((i) => i[0]).reduce((i, a2) => i.add(a2), m(0));
    let s2 = m(0);
    const r = [];
    for (const [i, a2] of t) {
      if (m(i).eq(0))
        continue;
      const u3 = s2.add(i);
      r.push(d(a2)._compress(s2.div(n2), u3.div(n2))), s2 = u3;
    }
    const o = z(...r);
    return o._steps = n2, o;
  }
  function Dn(...t) {
    t = t.map((r) => Array.isArray(r) ? r.map(d) : [d(r)]);
    const e = Y2(...t.map((r) => m(r.length)));
    let n2 = [];
    for (let r = 0; r < e; ++r)
      n2.push(...t.map((o) => o.length == 0 ? q2 : o[r % o.length]));
    n2 = n2.filter((r) => r.hasSteps && r._steps > 0);
    const s2 = n2.reduce((r, o) => r.add(o._steps), m(0));
    return n2 = $2(...n2), n2._steps = s2, n2;
  }
  var Gn = et2("take", function(t, e) {
    if (!e.hasSteps || e._steps.lte(0) || (t = m(t), t.eq(0)))
      return R;
    const n2 = t < 0;
    n2 && (t = t.abs());
    const s2 = t.div(e._steps);
    return s2.lte(0) ? R : s2.gte(1) ? e : n2 ? e.zoom(m(1).sub(s2), 1) : e.zoom(0, s2);
  });
  var Qn = et2("drop", function(t, e) {
    return e.hasSteps ? (t = m(t), t.lt(0) ? e.take(e._steps.add(t)) : e.take(m(0).sub(e._steps.sub(t)))) : R;
  });
  var Un = et2("extend", function(t, e) {
    return e.fast(t).expand(t);
  });
  var Em = et2("replicate", function(t, e) {
    return e.repeatCycles(t).fast(t).expand(t);
  });
  var Xn = et2("expand", function(t, e) {
    return e.withSteps((n2) => n2.mul(m(t)));
  });
  var Kn = et2("contract", function(t, e) {
    return e.withSteps((n2) => n2.div(m(t)));
  });
  f2.prototype.shrinklist = function(t) {
    const e = this;
    if (!e.hasSteps)
      return [e];
    let [n2, s2] = Array.isArray(t) ? t : [t, e._steps];
    if (n2 = m(n2), s2 === 0 || n2 === 0)
      return [e];
    const r = n2 > 0, o = [];
    if (r) {
      const i = m(1).div(e._steps).mul(n2);
      for (let a2 = 0; a2 < s2; ++a2) {
        const u3 = i.mul(a2);
        if (u3.gt(1))
          break;
        o.push([u3, 1]);
      }
    } else {
      n2 = m(0).sub(n2);
      const i = m(1).div(e._steps).mul(n2);
      for (let a2 = 0; a2 < s2; ++a2) {
        const u3 = m(1).sub(i.mul(a2));
        if (u3.lt(0))
          break;
        o.push([m(0), u3]);
      }
    }
    return o.map((i) => e.zoom(...i));
  };
  var Yn = (t, e) => e.shrinklist(t);
  var Zn = l(
    "shrink",
    function(t, e) {
      if (!e.hasSteps)
        return R;
      const n2 = e.shrinklist(t), s2 = $2(...n2);
      return s2._steps = n2.reduce((r, o) => r.add(o._steps), m(0)), s2;
    },
    true,
    false,
    (t) => t.stepJoin()
  );
  var jm = l(
    "grow",
    function(t, e) {
      if (!e.hasSteps)
        return R;
      const n2 = e.shrinklist(m(0).sub(t));
      n2.reverse();
      const s2 = $2(...n2);
      return s2._steps = n2.reduce((r, o) => r.add(o._steps), m(0)), s2;
    },
    true,
    false,
    (t) => t.stepJoin()
  );
  var ts = function(t, ...e) {
    return t.tour(...e);
  };
  f2.prototype.tour = function(...t) {
    return $2(
      ...[].concat(
        ...t.map((e, n2) => [...t.slice(0, t.length - n2), this, ...t.slice(t.length - n2)]),
        this,
        ...t
      )
    );
  };
  var es = function(...t) {
    t = t.filter((s2) => s2.hasSteps);
    const e = Z2(...t.map((s2) => s2._slow(s2._steps))), n2 = Y2(...t.map((s2) => s2._steps));
    return e._fast(n2).setSteps(n2);
  };
  var Jm = $2;
  var ns = $2;
  var $m = $2;
  var Nm = Dn;
  var Lm = $t2;
  f2.prototype.s_polymeter = f2.prototype.polymeter;
  var Rm = Zn;
  f2.prototype.s_taper = f2.prototype.shrink;
  var Wm = Yn;
  f2.prototype.s_taperlist = f2.prototype.shrinklist;
  var Fm = Gn;
  f2.prototype.s_add = f2.prototype.take;
  var Im = Qn;
  f2.prototype.s_sub = f2.prototype.drop;
  var Vm = Xn;
  f2.prototype.s_expand = f2.prototype.expand;
  var Hm = Un;
  f2.prototype.s_extend = f2.prototype.extend;
  var Dm = Kn;
  f2.prototype.s_contract = f2.prototype.contract;
  var Gm = ts;
  f2.prototype.s_tour = f2.prototype.tour;
  var Qm = es;
  f2.prototype.s_zip = f2.prototype.zip;
  var Um = Vn;
  f2.prototype.steps = f2.prototype.pace;
  var Xm = l("chop", function(t, e) {
    const s2 = Array.from({ length: t }, (i, a2) => a2).map((i) => ({ begin: i / t, end: (i + 1) / t })), r = function(i, a2) {
      if ("begin" in i && "end" in i && i.begin !== void 0 && i.end !== void 0) {
        const u3 = i.end - i.begin;
        a2 = { begin: i.begin + a2.begin * u3, end: i.begin + a2.end * u3 };
      }
      return Object.assign({}, i, a2);
    }, o = function(i) {
      return Q2(s2.map((a2) => r(i, a2)));
    };
    return e.squeezeBind(o).setSteps(J2 ? m(t).mulmaybe(e._steps) : void 0);
  });
  var Km = l("striate", function(t, e) {
    const s2 = Array.from({ length: t }, (o, i) => i).map((o) => ({ begin: o / t, end: (o + 1) / t })), r = Z2(...s2);
    return e.set(r)._fast(t).setSteps(J2 ? m(t).mulmaybe(e._steps) : void 0);
  });
  var he2 = function(t, e, n2 = 0.5) {
    return e.speed(1 / t * n2).unit("c").slow(t);
  };
  var ss = l(
    "slice",
    function(t, e, n2) {
      return t.innerBind(
        (s2) => e.outerBind(
          (r) => n2.outerBind((o) => {
            o = o instanceof Object ? o : { s: o };
            const i = Array.isArray(s2) ? s2[r] : r / s2, a2 = Array.isArray(s2) ? s2[r + 1] : (r + 1) / s2;
            return C2({ begin: i, end: a2, _slices: s2, ...o });
          })
        )
      ).setSteps(e._steps);
    },
    false
    // turns off auto-patternification
  );
  f2.prototype.onTriggerTime = function(t) {
    return this.onTrigger((e, n2, s2, r) => {
      const o = r - n2;
      window.setTimeout(() => {
        t(e);
      }, o * 1e3);
    }, false);
  };
  var Ym = l(
    "splice",
    function(t, e, n2) {
      const s2 = ss(t, e, n2);
      return new f2((r) => {
        const o = r.controls._cps || 1;
        return s2.query(r).map(
          (a2) => a2.withValue((u3) => ({
            speed: o / u3._slices / a2.whole.duration * (u3.speed || 1),
            unit: "c",
            ...u3
          }))
        );
      }).setSteps(e._steps);
    },
    false
    // turns off auto-patternification
  );
  var { loopAt: Zm, loopat: ty } = l(["loopAt", "loopat"], function(t, e) {
    const n2 = e._steps ? e._steps.div(t) : void 0;
    return new f2((s2) => he2(t, e, s2.controls._cps).query(s2), n2);
  });
  var ey = l(
    "fit",
    (t) => t.withHaps(
      (e, n2) => e.map(
        (s2) => s2.withValue((r) => {
          const o = ("end" in r ? r.end : 1) - ("begin" in r ? r.begin : 0);
          return {
            ...r,
            speed: (n2.controls._cps || 1) / s2.whole.duration * o,
            unit: "c"
          };
        })
      )
    )
  );
  var { loopAtCps: ny, loopatcps: sy } = l(["loopAtCps", "loopatcps"], function(t, e, n2) {
    return he2(t, n2, e);
  });
  var ry = (t) => C2(1).withValue(() => d(t())).innerJoin();
  var te2 = (t) => t < 0.5 ? 1 : 1 - (t - 0.5) / 0.5;
  var rs = (t, e, n2) => {
    e = d(e), t = d(t), n2 = d(n2);
    let s2 = e.fmap((o) => ({ gain: te2(o) })), r = e.fmap((o) => ({ gain: te2(1 - o) }));
    return z(t.mul(s2), n2.mul(r));
  };
  f2.prototype.xfade = function(t, e) {
    return rs(this, t, e);
  };
  var os = (t) => (e, n2, s2) => {
    e = m(e).mod(n2), n2 = m(n2);
    const r = e.div(n2), o = e.add(1).div(n2);
    return t(s2.fmap((i) => C2(i)._compress(r, o)));
  };
  var { beat: oy } = l(
    ["beat"],
    os((t) => t.innerJoin())
  );
  var de2 = (t, e, n2) => {
    n2 = m(n2);
    const s2 = m(1).div(t.length), r = (a2) => {
      const u3 = [];
      for (const [p2, h] of a2.entries())
        h && u3.push([m(p2).div(a2.length), h]);
      return u3;
    }, o = Pt2(
      ([a2, u3], [p2, h]) => {
        const y3 = n2.mul(p2 - a2).add(a2), g3 = y3.add(s2);
        return new B2(y3, g3);
      },
      r(t),
      r(e)
    );
    function i(a2) {
      const u3 = a2.span.begin.sam(), p2 = a2.span.cycleArc(), h = [];
      for (const y3 of o) {
        const g3 = y3.intersection(p2);
        g3 !== void 0 && h.push(
          new S2(
            y3.withTime((v2) => v2.add(u3)),
            g3.withTime((v2) => v2.add(u3)),
            true
          )
        );
      }
      return h;
    }
    return new f2(i).splitQueries();
  };
  var cy = (t, e, n2) => (t = d(t), e = d(e), n2 = d(n2), t.innerBind((s2) => e.innerBind((r) => n2.innerBind((o) => de2(s2, r, o)))));
  var U2 = function(t) {
    const e = function(n2, s2) {
      const r = d(n2).fmap((o) => Array.isArray(o) ? [...o, t] : [o, 1, t]);
      return s2 ? s2.distort(r) : C2({}).distort(r);
    };
    return f2.prototype[t] = function(n2) {
      return e(n2, this);
    }, e;
  };
  var iy = U2("soft");
  var uy = U2("hard");
  var ay = U2("cubic");
  var ly = U2("diode");
  var py = U2("asym");
  var fy = U2("fold");
  var hy = U2("sinefold");
  var dy = U2("chebyshev");
  var me2 = (t) => {
    let n2 = C2(w2((...s2) => s2, null, t.length));
    for (const s2 of t) n2 = n2.appBoth(d(s2));
    return n2;
  };
  var vt2 = (t) => Array.isArray(t) ? me2(t) : d(t);
  f2.prototype.partials = function(t) {
    return this.withValue((e) => (n2) => ({ ...e, partials: n2 })).appLeft(vt2(t));
  };
  var my = (t) => vt2(t).as("partials");
  f2.prototype.phases = function(t) {
    return this.withValue((e) => (n2) => ({ ...e, phases: n2 })).appLeft(vt2(t));
  };
  var yy = (t) => vt2(t).as("phases");
  f2.prototype.FX = function(...t) {
    return t = t.map(d), this.withValue((e) => (n2) => {
      const s2 = e.FX ?? [];
      return { ...e, FX: s2.concat(n2) };
    }).appLeft(me2(t));
  };
  var cs = (t) => {
    let n2 = C2(w2((...s2) => s2, null, t.length));
    for (const s2 of t) n2 = n2.appLeft(s2);
    return n2;
  };
  f2.prototype.worklet = function(t, ...e) {
    return e = e.map(d), this.outerBind((n2) => cs(e).withValue((s2) => {
      const r = n2.workletInputs ?? [];
      return { ...n2, workletSrc: t, workletInputs: r.concat(s2) };
    }));
  };
  var wy = (...t) => C2({}).worklet(...t);
  function Nt2(t) {
    let e = Array.isArray(t);
    t = e ? t : [t];
    const n2 = t[0], s2 = (o) => {
      let i;
      if (typeof o == "object" && o.value !== void 0 && (i = { ...o }, o = o.value, delete i.value), e && Array.isArray(o)) {
        const a2 = i || {};
        return o.forEach((u3, p2) => {
          p2 < t.length && (a2[t[p2]] = u3);
        }), a2;
      } else return i ? (i[n2] = o, i) : { [n2]: o };
    }, r = function(o, i) {
      return i ? typeof o > "u" ? i.fmap(s2) : i.set(d(o).withValue(s2)) : d(o).withValue(s2);
    };
    return f2.prototype[n2] = function(o) {
      return r(o, this);
    }, r;
  }
  var at2 = /* @__PURE__ */ new Map();
  function is(t) {
    return at2.has(t);
  }
  function c2(t, ...e) {
    const n2 = Array.isArray(t) ? t[0] : t;
    let s2 = {};
    return s2[n2] = Nt2(t), at2.set(n2, n2), e.forEach((r) => {
      s2[r] = s2[n2], at2.set(r, n2), f2.prototype[r] = f2.prototype[n2];
    }), s2;
  }
  function V2(t, e, ...n2) {
    t = Array.isArray(t) ? t : [t];
    let s2 = {};
    for (let r = 1; r <= e; r++) {
      let o = [...n2], i = [...t];
      if (r === 1) {
        const u3 = o.map((h) => `${h}1`), p2 = i.map((h) => `${h}1`);
        o = o.concat(u3).concat(p2);
      } else
        o = o.map((u3) => `${u3}${r}`), i = i.map((u3) => `${u3}${r}`);
      const a2 = c2(i, ...o);
      s2 = { ...s2, ...a2 };
    }
    return s2;
  }
  var { s: us, sound: as } = c2(["s", "n", "gain"], "sound");
  var { wt: ls, wavetablePosition: ps } = c2("wt", "wavetablePosition");
  var { wtenv: fs } = c2("wtenv");
  var { wtattack: hs, wtatt: ds } = c2("wtattack", "wtatt");
  var { wtdecay: ms, wtdec: ys } = c2("wtdecay", "wtdec");
  var { wtsustain: ws, wtsus: gs } = c2("wtsustain", "wtsus");
  var { wtrelease: bs, wtrel: _s } = c2("wtrelease", "wtrel");
  var { wtrate: vs } = c2("wtrate");
  var { wtsync: ks } = c2("wtsync");
  var { wtdepth: qs } = c2("wtdepth");
  var { wtshape: Ss } = c2("wtshape");
  var { wtdc: As } = c2("wtdc");
  var { wtskew: Ts } = c2("wtskew");
  var { warp: Cs, wavetableWarp: xs } = c2("warp", "wavetableWarp");
  var { warpattack: Bs, warpatt: Os } = c2("warpattack", "warpatt");
  var { warpdecay: zs, warpdec: Ms } = c2("warpdecay", "warpdec");
  var { warpsustain: Ps, warpsus: Es } = c2("warpsustain", "warpsus");
  var { warprelease: js, warprel: Js } = c2("warprelease", "warprel");
  var { warprate: $s } = c2("warprate");
  var { warpdepth: Ns } = c2("warpdepth");
  var { warpshape: Ls } = c2("warpshape");
  var { warpdc: Rs } = c2("warpdc");
  var { warpskew: Ws } = c2("warpskew");
  var { warpmode: Fs, wavetableWarpMode: Is } = c2("warpmode", "wavetableWarpMode");
  var { wtphaserand: Vs, wavetablePhaseRand: Hs } = c2("wtphaserand", "wavetablePhaseRand");
  var { warpenv: Ds } = c2("warpenv");
  var { warpsync: Gs } = c2("warpsync");
  var { source: Qs, src: Us } = c2("source", "src");
  var { n: Xs } = c2("n");
  var { note: Ks } = c2(["note", "n"]);
  var { accelerate: Ys } = c2("accelerate");
  var { velocity: Zs, vel: tr } = c2("velocity", "vel");
  var { gain: er } = c2("gain");
  var { postgain: nr } = c2("postgain");
  var { amp: sr } = c2("amp");
  var { attack: rr, att: or } = c2("attack", "att");
  var { fmh: cr, fmh1: ir, fmh2: ur, fmh3: ar, fmh4: lr, fmh5: pr, fmh6: fr, fmh7: hr, fmh8: dr } = V2(["fmh", "fmi"], 8, "fmh");
  var { fmi: mr, fmi1: yr, fmi2: wr, fmi3: gr, fmi4: br, fmi5: _r, fmi6: vr, fmi7: kr, fmi8: qr, fm: Sr, fm1: Ar, fm2: Tr, fm3: Cr, fm4: xr, fm5: Br, fm6: Or, fm7: zr, fm8: Mr } = V2(["fmi", "fmh"], 8, "fm");
  var { fmenv: Pr, fmenv1: Er, fmenv2: jr, fmenv3: Jr, fmenv4: $r, fmenv5: Nr, fmenv6: Lr, fmenv7: Rr, fmenv8: Wr } = V2(
    "fmenv",
    8
  );
  var {
    fmattack: Fr,
    fmattack1: Ir,
    fmattack2: Vr,
    fmattack3: Hr,
    fmattack4: Dr,
    fmattack5: Gr,
    fmattack6: Qr,
    fmattack7: Ur,
    fmattack8: Xr,
    fmatt: Kr,
    fmatt1: Yr,
    fmatt2: Zr,
    fmatt3: to,
    fmatt4: eo,
    fmatt5: no,
    fmatt6: so,
    fmatt7: ro,
    fmatt8: oo
  } = V2("fmattack", 8, "fmatt");
  var { fmwave: co, fmwave1: io, fmwave2: uo, fmwave3: ao, fmwave4: lo, fmwave5: po, fmwave6: fo, fmwave7: ho, fmwave8: mo } = V2(
    "fmwave",
    8
  );
  var {
    fmdecay: yo,
    fmdecay1: wo,
    fmdecay2: go,
    fmdecay3: bo,
    fmdecay4: _o,
    fmdecay5: vo,
    fmdecay6: ko,
    fmdecay7: qo,
    fmdecay8: So,
    fmdec: Ao,
    fmdec1: To,
    fmdec2: Co,
    fmdec3: xo,
    fmdec4: Bo,
    fmdec5: Oo,
    fmdec6: zo,
    fmdec7: Mo,
    fmdec8: Po
  } = V2("fmdecay", 8, "fmdec");
  var {
    fmsustain: Eo,
    fmsustain1: jo,
    fmsustain2: Jo,
    fmsustain3: $o,
    fmsustain4: No,
    fmsustain5: Lo,
    fmsustain6: Ro,
    fmsustain7: Wo,
    fmsustain8: Fo,
    fmsus: Io,
    fmsus1: Vo,
    fmsus2: Ho,
    fmsus3: Do,
    fmsus4: Go,
    fmsus5: Qo,
    fmsus6: Uo,
    fmsus7: Xo,
    fmsus8: Ko
  } = V2("fmsustain", 8, "fmsus");
  var {
    fmrelease: Yo,
    fmrelease1: Zo,
    fmrelease2: tc,
    fmrelease3: ec,
    fmrelease4: nc,
    fmrelease5: sc,
    fmrelease6: rc,
    fmrelease7: oc,
    fmrelease8: cc,
    fmrel: ic,
    fmrel1: uc,
    fmrel2: ac,
    fmrel3: lc,
    fmrel4: pc,
    fmrel5: fc,
    fmrel6: hc,
    fmrel7: dc,
    fmrel8: mc
  } = V2("fmrelease", 8, "fmrel");
  for (let t = 0; t <= 8; t++)
    for (let e = 0; e <= 8; e++)
      c2(`fmi${t}${e}`, `fm${t}${e}`);
  var { bank: yc } = c2("bank");
  var { chorus: wc } = c2("chorus");
  var { analyze: gc } = c2("analyze");
  var { fft: bc } = c2("fft");
  var { decay: _c, dec: vc } = c2("decay", "dec");
  var { sustain: kc, sus: qc } = c2("sustain", "sus");
  var { release: Sc, rel: Ac } = c2("release", "rel");
  var { hold: Tc } = c2("hold");
  var { bandf: Cc, bpf: xc, bp: Bc } = c2(["bandf", "bandq", "bpenv"], "bpf", "bp");
  var { bandq: Oc, bpq: zc } = c2("bandq", "bpq");
  var { begin: Mc } = c2("begin");
  var { end: Pc } = c2("end");
  var { loop: Ec } = c2("loop");
  var { loopBegin: jc, loopb: Jc } = c2("loopBegin", "loopb");
  var { loopEnd: $c, loope: Nc } = c2("loopEnd", "loope");
  var { crush: Lc } = c2("crush");
  var { coarse: Rc } = c2("coarse");
  var { tremolo: Wc, trem: Fc } = c2(["tremolo", "tremolodepth", "tremoloskew", "tremolophase"], "trem");
  var { tremolosync: Ic } = c2(
    ["tremolosync", "tremolodepth", "tremoloskew", "tremolophase"],
    "tremsync"
  );
  var { tremolodepth: Vc } = c2("tremolodepth", "tremdepth");
  var { tremoloskew: Hc } = c2("tremoloskew", "tremskew");
  var { tremolophase: Dc } = c2("tremolophase", "tremphase");
  var { tremoloshape: Gc } = c2("tremoloshape", "tremshape");
  var { drive: Qc } = c2("drive");
  var { duck: Uc } = c2("duckorbit", "duck");
  var { duckdepth: Xc } = c2("duckdepth");
  var { duckonset: Kc } = c2("duckonset", "duckons");
  var { duckattack: Yc } = c2("duckattack", "duckatt");
  var { byteBeatExpression: Zc, bbexpr: ti2 } = c2("byteBeatExpression", "bbexpr");
  var { byteBeatStartTime: ei2, bbst: ni2 } = c2("byteBeatStartTime", "bbst");
  var { channels: si2, ch: ri2 } = c2("channels", "ch");
  var { pw: oi2 } = c2(["pw", "pwrate", "pwsweep"]);
  var { pwrate: ci2 } = c2("pwrate");
  var { pwsweep: ii2 } = c2("pwsweep");
  var { phaserrate: ui2, ph: ai2, phaser: li2 } = c2(
    ["phaserrate", "phaserdepth", "phasercenter", "phasersweep"],
    "ph",
    "phaser"
  );
  var { phasersweep: pi2, phs: fi2 } = c2("phasersweep", "phs");
  var { phasercenter: hi2, phc: di2 } = c2("phasercenter", "phc");
  var { phaserdepth: mi2, phd: yi2, phasdp: wi2 } = c2("phaserdepth", "phd", "phasdp");
  var { channel: gi2 } = c2("channel");
  var { cut: bi2 } = c2("cut");
  var { cutoff: _i2, ctf: vi2, lpf: ki2, lp: qi2 } = c2(["cutoff", "resonance", "lpenv"], "ctf", "lpf", "lp");
  var { lpenv: Si2, lpe: Ai2 } = c2("lpenv", "lpe");
  var { hpenv: Ti2, hpe: Ci2 } = c2("hpenv", "hpe");
  var { bpenv: xi2, bpe: Bi2 } = c2("bpenv", "bpe");
  var { lpattack: Oi2, lpa: zi2 } = c2("lpattack", "lpa");
  var { hpattack: Mi2, hpa: Pi2 } = c2("hpattack", "hpa");
  var { bpattack: Ei2, bpa: ji2 } = c2("bpattack", "bpa");
  var { lpdecay: Ji2, lpd: $i2 } = c2("lpdecay", "lpd");
  var { hpdecay: Ni2, hpd: Li2 } = c2("hpdecay", "hpd");
  var { bpdecay: Ri2, bpd: Wi2 } = c2("bpdecay", "bpd");
  var { lpsustain: Fi2, lps: Ii2 } = c2("lpsustain", "lps");
  var { hpsustain: Vi2, hps: Hi2 } = c2("hpsustain", "hps");
  var { bpsustain: Di2, bps: Gi2 } = c2("bpsustain", "bps");
  var { lprelease: Qi2, lpr: Ui2 } = c2("lprelease", "lpr");
  var { hprelease: Xi2, hpr: Ki2 } = c2("hprelease", "hpr");
  var { bprelease: Yi2, bpr: Zi2 } = c2("bprelease", "bpr");
  var { ftype: tu } = c2("ftype");
  var { fanchor: eu } = c2("fanchor");
  var { lprate: nu } = c2("lprate");
  var { lpsync: su } = c2("lpsync");
  var { lpdepth: ru } = c2("lpdepth");
  var { lpdepthfrequency: ou, lpdepthfreq: cu } = c2("lpdepthfrequency", "lpdepthfreq");
  var { lpshape: iu } = c2("lpshape");
  var { lpdc: uu } = c2("lpdc");
  var { lpskew: au } = c2("lpskew");
  var { bprate: lu } = c2("bprate");
  var { bpsync: pu } = c2("bpsync");
  var { bpdepth: fu } = c2("bpdepth");
  var { bpdepthfrequency: hu, bpdepthfreq: du } = c2("bpdepthfrequency", "bpdepthfreq");
  var { bpshape: mu } = c2("bpshape");
  var { bpdc: yu } = c2("bpdc");
  var { bpskew: wu } = c2("bpskew");
  var { hprate: gu } = c2("hprate");
  var { hpsync: bu } = c2("hpsync");
  var { hpdepth: _u } = c2("hpdepth");
  var { hpdepthfrequency: vu, hpdepthfreq: ku } = c2("hpdepthfrequency", "hpdepthfreq");
  var { hpshape: qu } = c2("hpshape");
  var { hpdc: Su } = c2("hpdc");
  var { hpskew: Au } = c2("hpskew");
  var { vib: Tu, vibrato: Cu, v: xu } = c2(["vib", "vibmod"], "vibrato", "v");
  var { noise: Bu } = c2("noise");
  var { vibmod: Ou, vmod: zu } = c2(["vibmod", "vib"], "vmod");
  var { hcutoff: Mu, hpf: Pu, hp: Eu } = c2(["hcutoff", "hresonance", "hpenv"], "hpf", "hp");
  var { hresonance: ju, hpq: Ju } = c2("hresonance", "hpq");
  var { resonance: $u, lpq: Nu } = c2("resonance", "lpq");
  var { djf: Lu } = c2("djf");
  var { delay: Ru } = c2(["delay", "delaytime", "delayfeedback"]);
  var { delayfeedback: Wu, delayfb: Fu, dfb: Iu } = c2("delayfeedback", "delayfb", "dfb");
  var { delayspeed: Vu } = c2("delayspeed");
  var { delaytime: Hu, delayt: Du, dt: Gu } = c2("delaytime", "delayt", "dt");
  var { delaysync: Qu } = c2("delaysync");
  var { lock: Uu } = c2("lock");
  var { detune: Xu, det: Ku } = c2("detune", "det");
  var { unison: Yu } = c2("unison");
  var { spread: Zu } = c2("spread");
  var { dry: ta } = c2("dry");
  var { fadeTime: ea, fadeOutTime: na } = c2("fadeTime", "fadeOutTime");
  var { fadeInTime: sa } = c2("fadeInTime");
  var { freq: ra } = c2("freq");
  var { pattack: oa, patt: ca } = c2("pattack", "patt");
  var { pdecay: ia, pdec: ua } = c2("pdecay", "pdec");
  var { psustain: aa, psus: la } = c2("psustain", "psus");
  var { prelease: pa, prel: fa } = c2("prelease", "prel");
  var { penv: ha } = c2("penv");
  var { pcurve: da } = c2("pcurve");
  var { panchor: ma } = c2("panchor");
  var { gate: ya, gat: wa } = c2("gate", "gat");
  var { leslie: ga } = c2("leslie");
  var { lrate: ba } = c2("lrate");
  var { lsize: _a } = c2("lsize");
  var { activeLabel: va } = c2("activeLabel");
  var { label: ka } = c2(["label", "activeLabel"]);
  var { degree: qa } = c2("degree");
  var { mtranspose: Sa } = c2("mtranspose");
  var { ctranspose: Aa } = c2("ctranspose");
  var { harmonic: Ta } = c2("harmonic");
  var { stepsPerOctave: Ca } = c2("stepsPerOctave");
  var { octaveR: xa } = c2("octaveR");
  var { nudge: Ba } = c2("nudge");
  var { octave: Oa, oct: za } = c2("octave", "oct");
  var { orbit: Ma } = c2("orbit", "o");
  var { bus: Pa } = c2("bus");
  var { busgain: Ea, bgain: ja } = c2("busgain", "bgain");
  var { overgain: Ja } = c2("overgain");
  var { overshape: $a } = c2("overshape");
  var { pan: Na } = c2("pan");
  var { panspan: La } = c2("panspan");
  var { pansplay: Ra } = c2("pansplay");
  var { panwidth: Wa } = c2("panwidth");
  var { panorient: Fa } = c2("panorient");
  var { slide: Ia } = c2("slide");
  var { semitone: Va } = c2("semitone");
  var { voice: Ha } = c2("voice");
  var { chord: Da } = c2("chord");
  var { dictionary: Ga, dict: Qa } = c2("dictionary", "dict");
  var { anchor: Ua } = c2("anchor");
  var { offset: Xa } = c2("offset");
  var { octaves: Ka } = c2("octaves");
  var { mode: Ya } = c2(["mode", "anchor"]);
  var { room: Za } = c2(["room", "size"]);
  var { roomlp: tl, rlp: el } = c2("roomlp", "rlp");
  var { roomdim: nl, rdim: sl } = c2("roomdim", "rdim");
  var { roomfade: rl, rfade: ol } = c2("roomfade", "rfade");
  var { ir: cl, iresponse: il } = c2(["ir", "i"], "iresponse");
  var { irspeed: ul } = c2("irspeed");
  var { irbegin: al } = c2("irbegin");
  var { roomsize: ll, size: pl, sz: fl, rsize: hl } = c2("roomsize", "size", "sz", "rsize");
  var { shape: dl } = c2(["shape", "shapevol"]);
  var { distort: ml, dist: yl } = c2(["distort", "distortvol", "distorttype"], "dist");
  var { distortvol: wl } = c2("distortvol", "distvol");
  var { distorttype: gl } = c2("distorttype", "disttype");
  var { compressor: bl } = c2([
    "compressor",
    "compressorRatio",
    "compressorKnee",
    "compressorAttack",
    "compressorRelease"
  ]);
  var { compressorKnee: _l } = c2("compressorKnee");
  var { compressorRatio: vl } = c2("compressorRatio");
  var { compressorAttack: kl } = c2("compressorAttack");
  var { compressorRelease: ql } = c2("compressorRelease");
  var { speed: ye2 } = c2("speed");
  var { stretch: Sl } = c2("stretch");
  var { unit: Al } = c2("unit");
  var { squiz: Tl } = c2("squiz");
  var { vowel: Cl } = c2("vowel");
  var { waveloss: xl } = c2("waveloss");
  var { density: Bl } = c2("density");
  var { expression: Ol } = c2("expression");
  var { sustainpedal: zl } = c2("sustainpedal");
  var { fshift: Ml } = c2("fshift");
  var { fshiftnote: Pl } = c2("fshiftnote");
  var { fshiftphase: El } = c2("fshiftphase");
  var { triode: jl } = c2("triode");
  var { krush: Jl } = c2("krush");
  var { kcutoff: $l } = c2("kcutoff");
  var { octer: Nl } = c2("octer");
  var { octersub: Ll } = c2("octersub");
  var { octersubsub: Rl } = c2("octersubsub");
  var { ring: Wl } = c2("ring");
  var { ringf: Fl } = c2("ringf");
  var { ringdf: Il } = c2("ringdf");
  var { freeze: Vl } = c2("freeze");
  var { xsdelay: Hl } = c2("xsdelay");
  var { tsdelay: Dl } = c2("tsdelay");
  var { real: Gl } = c2("real");
  var { imag: Ql } = c2("imag");
  var { enhance: Ul } = c2("enhance");
  var { comb: Xl } = c2("comb");
  var { smear: Kl } = c2("smear");
  var { scram: Yl } = c2("scram");
  var { binshift: Zl } = c2("binshift");
  var { hbrick: tp } = c2("hbrick");
  var { lbrick: ep } = c2("lbrick");
  var { frameRate: np } = c2("frameRate");
  var { frames: sp } = c2("frames");
  var { hours: rp } = c2("hours");
  var { minutes: op } = c2("minutes");
  var { seconds: cp } = c2("seconds");
  var { songPtr: ip } = c2("songPtr");
  var { uid: up } = c2("uid");
  var { val: ap } = c2("val");
  var { cps: lp } = c2("cps");
  var { clip: pp, legato: fp } = c2("clip", "legato");
  var { duration: hp, dur: dp } = c2("duration", "dur");
  var { zrand: mp } = c2("zrand");
  var { curve: yp } = c2("curve");
  var { deltaSlide: wp } = c2("deltaSlide");
  var { pitchJump: gp } = c2("pitchJump");
  var { pitchJumpTime: bp } = c2("pitchJumpTime");
  var { znoise: _p } = c2("znoise");
  var { zmod: vp } = c2("zmod");
  var { zcrush: kp } = c2("zcrush");
  var { zdelay: qp } = c2("zdelay");
  var { zzfx: Sp } = c2("zzfx");
  var { color: Ap, colour: Tp } = c2(["color", "colour"]);
  var Cp = (...t) => t.reduce((e, n2) => Object.assign(e, { [n2]: Nt2(n2) }), {});
  var xp = l("adsr", (t, e) => {
    t = Array.isArray(t) ? t : [t];
    const [n2, s2, r, o] = t;
    return e.set({ attack: n2, decay: s2, sustain: r, release: o });
  });
  var Bp = l("ad", (t, e) => {
    t = Array.isArray(t) ? t : [t];
    const [n2, s2 = n2] = t;
    return e.attack(n2).decay(s2);
  });
  var Op = l("ds", (t, e) => {
    t = Array.isArray(t) ? t : [t];
    const [n2, s2 = 0] = t;
    return e.set({ decay: n2, sustain: s2 });
  });
  var zp = l("ar", (t, e) => {
    t = Array.isArray(t) ? t : [t];
    const [n2, s2 = n2] = t;
    return e.set({ attack: n2, release: s2 });
  });
  var { midichan: Mp } = c2("midichan");
  var { midimap: Pp } = c2("midimap");
  var { midiport: Ep } = c2("midiport");
  var { midicmd: jp } = c2("midicmd");
  var Jp = l("control", (t, e) => {
    if (!Array.isArray(t))
      throw new Error("control expects an array of [ccn, ccv]");
    const [n2, s2] = t;
    return e.ccn(n2).ccv(s2);
  });
  var { ccn: $p } = c2("ccn");
  var { ccv: Np } = c2("ccv");
  var { ctlNum: Lp } = c2("ctlNum");
  var { nrpnn: Rp } = c2("nrpnn");
  var { nrpv: Wp } = c2("nrpv");
  var { progNum: Fp } = c2("progNum");
  var Ip = l("sysex", (t, e) => {
    if (!Array.isArray(t))
      throw new Error("sysex expects an array of [id, data]");
    const [n2, s2] = t;
    return e.sysexid(n2).sysexdata(s2);
  });
  var { sysexid: Vp } = c2("sysexid");
  var { sysexdata: Hp } = c2("sysexdata");
  var { midibend: Dp } = c2("midibend");
  var { miditouch: Gp } = c2("miditouch");
  var { polyTouch: Qp } = c2("polyTouch");
  var { oschost: Up } = c2("oschost");
  var { oscport: Xp } = c2("oscport");
  var yt2 = (t) => at2.has(t) ? at2.get(t) : t;
  var Kp = l("as", (t, e) => (t = Array.isArray(t) ? t : [t], e.fmap((n2) => {
    n2 = Array.isArray(n2) ? n2 : [n2];
    const s2 = [];
    for (let r = 0; r < t.length; ++r)
      n2[r] !== void 0 && s2.push([yt2(t[r]), n2[r]]);
    return Object.fromEntries(s2);
  })));
  var Yp = l(
    "scrub",
    (t, e) => t.outerBind((n2) => {
      Array.isArray(n2) || (n2 = [n2]);
      const [s2, r = 1] = n2;
      return e.begin(s2).mul(ye2(r)).clip(1);
    }),
    false
  );
  var Bt2 = /* @__PURE__ */ new Map();
  var Zp = (t, e, ...n2) => {
    const s2 = Bt2.get(t) ?? /* @__PURE__ */ new Map(), r = /* @__PURE__ */ new Set([e, ...n2]);
    for (const o of r)
      s2.set(String(o).toLowerCase(), e);
    Bt2.set(t, s2);
  };
  var Lt2 = (t, e = []) => {
    for (const [n2, ...s2] of e)
      Zp(t, n2, ...s2);
  };
  var tf = (t, e) => {
    const n2 = Bt2.get(t);
    return n2 ? n2.get(String(e).toLowerCase()) ?? e : e;
  };
  Lt2("lfo", [
    ["control", "c"],
    ["subControl", "sc"],
    ["rate", "r"],
    ["depth", "dep", "dr"],
    ["depthabs", "da"],
    ["dcoffset", "dc"],
    ["shape", "sh"],
    ["skew", "sk"],
    ["curve", "cu"],
    ["sync", "s"],
    ["fxi"]
  ]);
  Lt2("env", [
    ["control", "c"],
    ["subControl", "sc"],
    ["attack", "att", "a"],
    ["decay", "dec", "d"],
    ["sustain", "sus", "s"],
    ["release", "rel", "r"],
    ["depth", "dep", "dr"],
    ["depthabs", "da"],
    ["acurve", "ac"],
    ["dcurve", "dc"],
    ["rcurve", "rc"],
    ["fxi"]
  ]);
  Lt2("bmod", [
    ["bus", "b"],
    ["control", "c"],
    ["subControl", "sc"],
    ["depth", "dep", "dr"],
    ["depthabs", "da"],
    ["dc"],
    ["fxi"]
  ]);
  f2.prototype.modulate = function(t, e, n2) {
    e = { control: void 0, ...e };
    const s2 = ["lfo", "env", "bmod"];
    if (!s2.includes(t))
      return E2(`[core] Modulation type ${t} not found. Please use one of 'lfo', 'env', 'bmod'`), this;
    let r = this, o;
    r = r.fmap((i) => (a2) => ({ v: i, id: a2 })).appLeft(d(n2));
    for (const [i, a2] of Object.entries(e)) {
      const u3 = tf(t, i), p2 = d(a2);
      r = r.fmap(({ v: h, id: y3 }) => (g3) => {
        if (o === void 0) {
          let _5 = yt2(Object.keys(h).at(-1));
          s2.includes(_5) && (_5 = `${_5}_${[...h[_5].__ids].at(-1)}`), o = _5;
        }
        h[t] ?? (h[t] = { __ids: /* @__PURE__ */ new Set() });
        const v2 = h[t];
        return y3 ?? (y3 = v2.__ids.size), v2[y3] ?? (v2[y3] = { control: o }), v2.__ids.add(y3), g3 === void 0 ? { v: h, id: y3 } : (u3 === "control" || u3 === "subControl" ? v2[y3][u3] = yt2(g3) : v2[y3][u3] = g3, { v: h, id: y3 });
      }).appLeft(p2);
    }
    return r.fmap(({ v: i }) => i);
  };
  f2.prototype.lfo = function(t, e) {
    return this.modulate("lfo", t, e);
  };
  var ef = (t) => C2({}).lfo(t);
  f2.prototype.env = function(t, e) {
    return this.modulate("env", t, e);
  };
  var nf = (t) => C2({}).env(t);
  f2.prototype.bmod = function(t, e) {
    return this.modulate("bmod", t, e);
  };
  var sf = (t) => C2({}).bmod(t);
  var { transient: rf } = c2(["transient", "transsustain"]);
  var { FXrelease: of, FXrel: cf, FXr: uf, fxr: af } = c2("FXrelease", "FXrel", "FXr", "fxr");
  var gy = /* @__PURE__ */ Object.freeze(/* @__PURE__ */ Object.defineProperty({
    __proto__: null,
    FXr: uf,
    FXrel: cf,
    FXrelease: of,
    accelerate: Ys,
    activeLabel: va,
    ad: Bp,
    adsr: xp,
    amp: sr,
    analyze: gc,
    anchor: Ua,
    ar: zp,
    as: Kp,
    att: or,
    attack: rr,
    bandf: Cc,
    bandq: Oc,
    bank: yc,
    bbexpr: ti2,
    bbst: ni2,
    begin: Mc,
    bgain: ja,
    binshift: Zl,
    bmod: sf,
    bp: Bc,
    bpa: ji2,
    bpattack: Ei2,
    bpd: Wi2,
    bpdc: yu,
    bpdecay: Ri2,
    bpdepth: fu,
    bpdepthfreq: du,
    bpdepthfrequency: hu,
    bpe: Bi2,
    bpenv: xi2,
    bpf: xc,
    bpq: zc,
    bpr: Zi2,
    bprate: lu,
    bprelease: Yi2,
    bps: Gi2,
    bpshape: mu,
    bpskew: wu,
    bpsustain: Di2,
    bpsync: pu,
    bus: Pa,
    busgain: Ea,
    byteBeatExpression: Zc,
    byteBeatStartTime: ei2,
    ccn: $p,
    ccv: Np,
    ch: ri2,
    channel: gi2,
    channels: si2,
    chord: Da,
    chorus: wc,
    clip: pp,
    coarse: Rc,
    color: Ap,
    colour: Tp,
    comb: Xl,
    compressor: bl,
    compressorAttack: kl,
    compressorKnee: _l,
    compressorRatio: vl,
    compressorRelease: ql,
    control: Jp,
    cps: lp,
    createParam: Nt2,
    createParams: Cp,
    crush: Lc,
    ctf: vi2,
    ctlNum: Lp,
    ctranspose: Aa,
    curve: yp,
    cut: bi2,
    cutoff: _i2,
    dec: vc,
    decay: _c,
    degree: qa,
    delay: Ru,
    delayfb: Fu,
    delayfeedback: Wu,
    delayspeed: Vu,
    delaysync: Qu,
    delayt: Du,
    delaytime: Hu,
    deltaSlide: wp,
    density: Bl,
    det: Ku,
    detune: Xu,
    dfb: Iu,
    dict: Qa,
    dictionary: Ga,
    dist: yl,
    distort: ml,
    distorttype: gl,
    distortvol: wl,
    djf: Lu,
    drive: Qc,
    dry: ta,
    ds: Op,
    dt: Gu,
    duck: Uc,
    duckattack: Yc,
    duckdepth: Xc,
    duckonset: Kc,
    dur: dp,
    duration: hp,
    end: Pc,
    enhance: Ul,
    env: nf,
    expression: Ol,
    fadeInTime: sa,
    fadeOutTime: na,
    fadeTime: ea,
    fanchor: eu,
    fft: bc,
    fm: Sr,
    fm1: Ar,
    fm2: Tr,
    fm3: Cr,
    fm4: xr,
    fm5: Br,
    fm6: Or,
    fm7: zr,
    fm8: Mr,
    fmatt: Kr,
    fmatt1: Yr,
    fmatt2: Zr,
    fmatt3: to,
    fmatt4: eo,
    fmatt5: no,
    fmatt6: so,
    fmatt7: ro,
    fmatt8: oo,
    fmattack: Fr,
    fmattack1: Ir,
    fmattack2: Vr,
    fmattack3: Hr,
    fmattack4: Dr,
    fmattack5: Gr,
    fmattack6: Qr,
    fmattack7: Ur,
    fmattack8: Xr,
    fmdec: Ao,
    fmdec1: To,
    fmdec2: Co,
    fmdec3: xo,
    fmdec4: Bo,
    fmdec5: Oo,
    fmdec6: zo,
    fmdec7: Mo,
    fmdec8: Po,
    fmdecay: yo,
    fmdecay1: wo,
    fmdecay2: go,
    fmdecay3: bo,
    fmdecay4: _o,
    fmdecay5: vo,
    fmdecay6: ko,
    fmdecay7: qo,
    fmdecay8: So,
    fmenv: Pr,
    fmenv1: Er,
    fmenv2: jr,
    fmenv3: Jr,
    fmenv4: $r,
    fmenv5: Nr,
    fmenv6: Lr,
    fmenv7: Rr,
    fmenv8: Wr,
    fmh: cr,
    fmh1: ir,
    fmh2: ur,
    fmh3: ar,
    fmh4: lr,
    fmh5: pr,
    fmh6: fr,
    fmh7: hr,
    fmh8: dr,
    fmi: mr,
    fmi1: yr,
    fmi2: wr,
    fmi3: gr,
    fmi4: br,
    fmi5: _r,
    fmi6: vr,
    fmi7: kr,
    fmi8: qr,
    fmrel: ic,
    fmrel1: uc,
    fmrel2: ac,
    fmrel3: lc,
    fmrel4: pc,
    fmrel5: fc,
    fmrel6: hc,
    fmrel7: dc,
    fmrel8: mc,
    fmrelease: Yo,
    fmrelease1: Zo,
    fmrelease2: tc,
    fmrelease3: ec,
    fmrelease4: nc,
    fmrelease5: sc,
    fmrelease6: rc,
    fmrelease7: oc,
    fmrelease8: cc,
    fmsus: Io,
    fmsus1: Vo,
    fmsus2: Ho,
    fmsus3: Do,
    fmsus4: Go,
    fmsus5: Qo,
    fmsus6: Uo,
    fmsus7: Xo,
    fmsus8: Ko,
    fmsustain: Eo,
    fmsustain1: jo,
    fmsustain2: Jo,
    fmsustain3: $o,
    fmsustain4: No,
    fmsustain5: Lo,
    fmsustain6: Ro,
    fmsustain7: Wo,
    fmsustain8: Fo,
    fmwave: co,
    fmwave1: io,
    fmwave2: uo,
    fmwave3: ao,
    fmwave4: lo,
    fmwave5: po,
    fmwave6: fo,
    fmwave7: ho,
    fmwave8: mo,
    frameRate: np,
    frames: sp,
    freeze: Vl,
    freq: ra,
    fshift: Ml,
    fshiftnote: Pl,
    fshiftphase: El,
    ftype: tu,
    fxr: af,
    gain: er,
    gat: wa,
    gate: ya,
    getControlName: yt2,
    harmonic: Ta,
    hbrick: tp,
    hcutoff: Mu,
    hold: Tc,
    hours: rp,
    hp: Eu,
    hpa: Pi2,
    hpattack: Mi2,
    hpd: Li2,
    hpdc: Su,
    hpdecay: Ni2,
    hpdepth: _u,
    hpdepthfreq: ku,
    hpdepthfrequency: vu,
    hpe: Ci2,
    hpenv: Ti2,
    hpf: Pu,
    hpq: Ju,
    hpr: Ki2,
    hprate: gu,
    hprelease: Xi2,
    hps: Hi2,
    hpshape: qu,
    hpskew: Au,
    hpsustain: Vi2,
    hpsync: bu,
    hresonance: ju,
    imag: Ql,
    ir: cl,
    irbegin: al,
    iresponse: il,
    irspeed: ul,
    isControlName: is,
    kcutoff: $l,
    krush: Jl,
    label: ka,
    lbrick: ep,
    legato: fp,
    leslie: ga,
    lfo: ef,
    lock: Uu,
    loop: Ec,
    loopBegin: jc,
    loopEnd: $c,
    loopb: Jc,
    loope: Nc,
    lp: qi2,
    lpa: zi2,
    lpattack: Oi2,
    lpd: $i2,
    lpdc: uu,
    lpdecay: Ji2,
    lpdepth: ru,
    lpdepthfreq: cu,
    lpdepthfrequency: ou,
    lpe: Ai2,
    lpenv: Si2,
    lpf: ki2,
    lpq: Nu,
    lpr: Ui2,
    lprate: nu,
    lprelease: Qi2,
    lps: Ii2,
    lpshape: iu,
    lpskew: au,
    lpsustain: Fi2,
    lpsync: su,
    lrate: ba,
    lsize: _a,
    midibend: Dp,
    midichan: Mp,
    midicmd: jp,
    midimap: Pp,
    midiport: Ep,
    miditouch: Gp,
    minutes: op,
    mode: Ya,
    mtranspose: Sa,
    n: Xs,
    noise: Bu,
    note: Ks,
    nrpnn: Rp,
    nrpv: Wp,
    nudge: Ba,
    oct: za,
    octave: Oa,
    octaveR: xa,
    octaves: Ka,
    octer: Nl,
    octersub: Ll,
    octersubsub: Rl,
    offset: Xa,
    orbit: Ma,
    oschost: Up,
    oscport: Xp,
    overgain: Ja,
    overshape: $a,
    pan: Na,
    panchor: ma,
    panorient: Fa,
    panspan: La,
    pansplay: Ra,
    panwidth: Wa,
    patt: ca,
    pattack: oa,
    pcurve: da,
    pdec: ua,
    pdecay: ia,
    penv: ha,
    ph: ai2,
    phasdp: wi2,
    phaser: li2,
    phasercenter: hi2,
    phaserdepth: mi2,
    phaserrate: ui2,
    phasersweep: pi2,
    phc: di2,
    phd: yi2,
    phs: fi2,
    pitchJump: gp,
    pitchJumpTime: bp,
    polyTouch: Qp,
    postgain: nr,
    prel: fa,
    prelease: pa,
    progNum: Fp,
    psus: la,
    psustain: aa,
    pw: oi2,
    pwrate: ci2,
    pwsweep: ii2,
    rdim: sl,
    real: Gl,
    registerControl: c2,
    registerMultiControl: V2,
    rel: Ac,
    release: Sc,
    resonance: $u,
    rfade: ol,
    ring: Wl,
    ringdf: Il,
    ringf: Fl,
    rlp: el,
    room: Za,
    roomdim: nl,
    roomfade: rl,
    roomlp: tl,
    roomsize: ll,
    rsize: hl,
    s: us,
    scram: Yl,
    scrub: Yp,
    seconds: cp,
    semitone: Va,
    shape: dl,
    size: pl,
    slide: Ia,
    smear: Kl,
    songPtr: ip,
    sound: as,
    source: Qs,
    speed: ye2,
    spread: Zu,
    squiz: Tl,
    src: Us,
    stepsPerOctave: Ca,
    stretch: Sl,
    sus: qc,
    sustain: kc,
    sustainpedal: zl,
    sysex: Ip,
    sysexdata: Hp,
    sysexid: Vp,
    sz: fl,
    transient: rf,
    trem: Fc,
    tremolo: Wc,
    tremolodepth: Vc,
    tremolophase: Dc,
    tremoloshape: Gc,
    tremoloskew: Hc,
    tremolosync: Ic,
    triode: jl,
    tsdelay: Dl,
    uid: up,
    unison: Yu,
    unit: Al,
    v: xu,
    val: ap,
    vel: tr,
    velocity: Zs,
    vib: Tu,
    vibmod: Ou,
    vibrato: Cu,
    vmod: zu,
    voice: Ha,
    vowel: Cl,
    warp: Cs,
    warpatt: Os,
    warpattack: Bs,
    warpdc: Rs,
    warpdec: Ms,
    warpdecay: zs,
    warpdepth: Ns,
    warpenv: Ds,
    warpmode: Fs,
    warprate: $s,
    warprel: Js,
    warprelease: js,
    warpshape: Ls,
    warpskew: Ws,
    warpsus: Es,
    warpsustain: Ps,
    warpsync: Gs,
    waveloss: xl,
    wavetablePhaseRand: Hs,
    wavetablePosition: ps,
    wavetableWarp: xs,
    wavetableWarpMode: Is,
    wt: ls,
    wtatt: ds,
    wtattack: hs,
    wtdc: As,
    wtdec: ys,
    wtdecay: ms,
    wtdepth: qs,
    wtenv: fs,
    wtphaserand: Vs,
    wtrate: vs,
    wtrel: _s,
    wtrelease: bs,
    wtshape: Ss,
    wtskew: Ts,
    wtsus: gs,
    wtsustain: ws,
    wtsync: ks,
    xsdelay: Hl,
    zcrush: kp,
    zdelay: qp,
    zmod: vp,
    znoise: _p,
    zrand: mp,
    zzfx: Sp
  }, Symbol.toStringTag, { value: "Module" }));
  var lf = function(t, e) {
    const [n2, s2] = t, [r, o] = e, [i, a2] = ue2(s2, r);
    return [
      [s2, n2 - s2],
      [Pt2((u3, p2) => u3.concat(p2), i, o), a2]
    ];
  };
  var pf = function(t, e) {
    const [n2, s2] = t, [r, o] = e, [i, a2] = ue2(n2, o);
    return [
      [n2, s2 - n2],
      [Pt2((p2, h) => p2.concat(h), r, i), a2]
    ];
  };
  var we2 = function(t, e) {
    const [n2, s2] = t;
    return Math.min(n2, s2) <= 1 ? [t, e] : we2(...n2 > s2 ? lf(t, e) : pf(t, e));
  };
  var ge2 = function(t, e) {
    const n2 = t < 0, s2 = Math.abs(t), r = e - s2, o = Array(s2).fill([1]), i = Array(r).fill([0]), a2 = we2([s2, r], [o, i]), u3 = G(a2[1][0]).concat(G(a2[1][1]));
    return n2 ? u3.map((p2) => 1 - p2) : u3;
  };
  var kt2 = function(t, e, n2) {
    const s2 = ge2(t, e);
    return n2 ? rn(s2, -n2) : s2;
  };
  var by = l("euclid", function(t, e, n2) {
    return n2.struct(kt2(t, e, 0));
  });
  var _y = l("bjork", function(t, e) {
    Array.isArray(t) || (t = [t]);
    const [n2, s2 = n2, r = 0] = t;
    return e.struct(kt2(n2, s2, r));
  });
  var { euclidrot: vy, euclidRot: ky } = l(["euclidrot", "euclidRot"], function(t, e, n2, s2) {
    return s2.struct(kt2(t, e, n2));
  });
  var be2 = function(t, e, n2, s2) {
    if (t < 1)
      return q2;
    const o = kt2(t, e, 0).join("").split("1").slice(1).map((i) => [i.length + 1, true]);
    return s2.struct(ns(...o)).late(m(n2).div(e));
  };
  var qy = l(["euclidLegato"], function(t, e, n2) {
    return be2(t, e, 0, n2);
  });
  var Sy = l(["euclidLegatoRot"], function(t, e, n2, s2) {
    return be2(t, e, n2, s2);
  });
  var { euclidish: Ay, eish: Ty } = l(["euclidish", "eish"], function(t, e, n2, s2) {
    const r = de2(ge2(t, e), new Array(t).fill(1), n2);
    return s2.struct(r).setSteps(e);
  });
  function ff(t, e, n2 = 0.05, s2 = 0.1, r = 0.1, o = globalThis.setInterval, i = globalThis.clearInterval, a2 = true) {
    let u3 = 0, p2 = 0, h = 10 ** 4, y3 = 0.01;
    const g3 = (x2) => n2 = x2(n2);
    r = r || s2 / 2;
    const v2 = () => {
      const x2 = t(), D4 = x2 + s2 + r;
      for (p2 === 0 && (p2 = x2 + y3); p2 < D4; )
        p2 = a2 ? Math.round(p2 * h) / h : p2, e(p2, n2, u3, x2), p2 += n2, u3++;
    };
    let _5;
    const O2 = () => {
      A4(), v2(), _5 = o(v2, s2 * 1e3);
    }, A4 = () => {
      _5 !== void 0 && i(_5), _5 = void 0;
    };
    return { setDuration: g3, start: O2, stop: () => {
      u3 = 0, p2 = 0, A4();
    }, pause: () => A4(), duration: n2, interval: s2, getPhase: () => p2, minLatency: y3 };
  }
  var hf = class {
    constructor({
      interval: e,
      onTrigger: n2,
      onToggle: s2,
      onError: r,
      getTime: o,
      latency: i = 0.1,
      setInterval: a2,
      clearInterval: u3,
      beforeStart: p2
    }) {
      this.started = false, this.beforeStart = p2, this.cps = 0.5, this.num_ticks_since_cps_change = 0, this.lastTick = 0, this.lastBegin = 0, this.lastEnd = 0, this.getTime = o, this.num_cycles_at_cps_change = 0, this.seconds_at_cps_change, this.onToggle = s2, this.latency = i, this.clock = ff(
        o,
        // called slightly before each cycle
        (h, y3, g3, v2) => {
          this.num_ticks_since_cps_change === 0 && (this.num_cycles_at_cps_change = this.lastEnd, this.seconds_at_cps_change = h), this.num_ticks_since_cps_change++;
          const O2 = this.num_ticks_since_cps_change * y3 * this.cps;
          try {
            const A4 = this.lastEnd;
            this.lastBegin = A4;
            const I3 = this.num_cycles_at_cps_change + O2;
            if (this.lastEnd = I3, this.lastTick = h, h < v2) {
              console.log("skip query: too late");
              return;
            }
            this.pattern.queryArc(A4, I3, { _cps: this.cps, cyclist: "cyclist" }).forEach((P3) => {
              if (P3.hasOnset()) {
                const x2 = (P3.whole.begin - this.num_cycles_at_cps_change) / this.cps + this.seconds_at_cps_change + i, D4 = P3.duration / this.cps, nt4 = x2 - h;
                n2?.(P3, nt4, D4, this.cps, x2), P3.value.cps !== void 0 && this.cps != P3.value.cps && (this.cps = P3.value.cps, this.num_ticks_since_cps_change = 0);
              }
            });
          } catch (A4) {
            zt2(A4), r?.(A4);
          }
        },
        e,
        // duration of each cycle
        0.1,
        0.1,
        a2,
        u3
      );
    }
    now() {
      if (!this.started)
        return 0;
      const e = this.getTime() - this.lastTick - this.clock.duration;
      return this.lastBegin + e * this.cps;
    }
    setStarted(e) {
      this.started = e, this.onToggle?.(e);
    }
    async start() {
      if (await this.beforeStart?.(), this.num_ticks_since_cps_change = 0, this.num_cycles_at_cps_change = 0, !this.pattern)
        throw new Error("Scheduler: no pattern set! call .setPattern first.");
      E2("[cyclist] start"), this.clock.start(), this.setStarted(true);
    }
    pause() {
      E2("[cyclist] pause"), this.clock.pause(), this.setStarted(false);
    }
    stop() {
      E2("[cyclist] stop"), this.clock.stop(), this.lastEnd = 0, this.setStarted(false);
    }
    async setPattern(e, n2 = false) {
      this.pattern = e, n2 && !this.started && await this.start();
    }
    setCps(e = 0.5) {
      this.cps !== e && (this.cps = e, this.num_ticks_since_cps_change = 0);
    }
    log(e, n2, s2) {
      const r = s2.filter((o) => o.hasOnset());
      console.log(`${e.toFixed(4)} - ${n2.toFixed(4)} ${Array(r.length).fill("I").join("")}`);
    }
  };
  var ct2 = {};
  var df = function() {
    mf();
  };
  var mf = function() {
    ct2 = {};
  };
  var Cy = l(
    "timeline",
    function(t, e) {
      t = d(t);
      const n2 = function(s2) {
        const r = !!s2.controls.cyclist, o = t.query(s2), i = [];
        for (const a2 of o) {
          const u3 = a2.value;
          let p2;
          if (u3 === 0)
            p2 = 0;
          else if (u3 in ct2)
            p2 = ct2[u3];
          else {
            const y3 = a2.wholeOrPart();
            !r || s2.span.begin.lt(y3.midpoint()) ? p2 = y3.begin : p2 = y3.end;
          }
          r && (ct2[u3] = p2, u3 !== 0 && delete ct2[-u3]);
          const h = e.late(p2).query(s2.setSpan(a2.part)).map((y3) => y3.setContext(y3.combineContext(a2)));
          i.push(...h);
        }
        return i;
      };
      return new f2(n2, e._steps);
    },
    false
  );
  var F2 = function(t, e, n2 = true) {
    const s2 = Array.isArray(t), r = Object.keys(t).length;
    return t = bn(t, d), r === 0 ? q2 : e.fmap((o) => {
      let i = o;
      return s2 && (i = n2 ? Math.round(i) % r : an(Math.round(i), 0, t.length - 1)), t[i];
    });
  };
  var yf = function(t, e) {
    return Array.isArray(e) && ([e, t] = [t, e]), wf(t, e);
  };
  var wf = l("pick", function(t, e) {
    return F2(t, e, false).innerJoin();
  });
  var gf = l("pickmod", function(t, e) {
    return F2(t, e, true).innerJoin();
  });
  var xy = l("pickF", function(t, e, n2) {
    return n2.apply(yf(t, e));
  });
  var By = l("pickmodF", function(t, e, n2) {
    return n2.apply(gf(t, e));
  });
  var Oy = l("pickOut", function(t, e) {
    return F2(t, e, false).outerJoin();
  });
  var zy = l("pickmodOut", function(t, e) {
    return F2(t, e, true).outerJoin();
  });
  var My = l("pickRestart", function(t, e) {
    return F2(t, e, false).restartJoin();
  });
  var Py = l("pickmodRestart", function(t, e) {
    return F2(t, e, true).restartJoin();
  });
  var Ey = l("pickReset", function(t, e) {
    return F2(t, e, false).resetJoin();
  });
  var jy = l("pickmodReset", function(t, e) {
    return F2(t, e, true).resetJoin();
  });
  var { inhabit: Jy, pickSqueeze: $y } = l(["inhabit", "pickSqueeze"], function(t, e) {
    return F2(t, e, false).squeezeJoin();
  });
  var { inhabitmod: Ny, pickmodSqueeze: Ly } = l(["inhabitmod", "pickmodSqueeze"], function(t, e) {
    return F2(t, e, true).squeezeJoin();
  });
  var Ry = (t, e) => (e = e.map(d), e.length == 0 ? q2 : t.fmap((n2) => {
    const s2 = bt2(Math.round(n2), e.length);
    return e[s2];
  }).squeezeJoin());
  var bf = class {
    constructor({ onTrigger: e, onToggle: n2, getTime: s2 }) {
      this.started = false, this.cps = 0.5, this.getTime = s2, this.time_at_last_tick_message = 0, this.collator = new _n({ getTargetClockTime: s2 }), this.onToggle = n2, this.latency = 0.1, this.cycle = 0, this.id = Math.round(Date.now() * Math.random()), this.worker = new SharedWorker(new URL(
        /* @vite-ignore */
        "" + new URL("assets/clockworker-ZDiUtESR.js", import_meta.url).href,
        import_meta.url
      )), this.worker.port.start(), this.channel = new BroadcastChannel("strudeltick");
      const r = (i) => {
        const { cps: a2, begin: u3, end: p2, cycle: h, time: y3 } = i;
        this.cps = a2, this.cycle = h;
        const g3 = this.collator.calculateOffset(y3) + y3;
        o(u3, p2, g3), this.time_at_last_tick_message = g3;
      }, o = (i, a2, u3) => {
        if (this.started === false)
          return;
        this.pattern.queryArc(i, a2, { _cps: this.cps, cyclist: "neocyclist" }).forEach((h) => {
          if (h.hasOnset()) {
            const g3 = Kt2(h.whole.begin - this.cycle, this.cps) + u3 + this.latency, v2 = Kt2(h.duration, this.cps);
            e?.(h, 0, v2, this.cps, g3);
          }
        });
      };
      this.channel.onmessage = (i) => {
        if (!this.started)
          return;
        const { payload: a2, type: u3 } = i.data;
        switch (u3) {
          case "tick":
            r(a2);
        }
      };
    }
    sendMessage(e, n2) {
      this.worker.port.postMessage({ type: e, payload: n2, id: this.id });
    }
    now() {
      const e = (this.getTime() - this.time_at_last_tick_message) * this.cps;
      return this.cycle + e;
    }
    setCps(e = 1) {
      this.sendMessage("cpschange", { cps: e });
    }
    setCycle(e) {
      this.sendMessage("setcycle", { cycle: e });
    }
    setStarted(e) {
      this.sendMessage("toggle", { started: e }), this.started = e, this.onToggle?.(e);
    }
    start() {
      E2("[cyclist] start"), this.setStarted(true);
    }
    stop() {
      E2("[cyclist] stop"), this.collator.reset(), this.setStarted(false);
    }
    setPattern(e, n2 = false) {
      this.pattern = e, n2 && !this.started && this.start();
    }
    log(e, n2, s2) {
      const r = s2.filter((o) => o.hasOnset());
      console.log(`${e.toFixed(4)} - ${n2.toFixed(4)} ${Array(r.length).fill("I").join("")}`);
    }
  };
  var Ot2;
  var _e2;
  var ve2;
  var ke2;
  var qe2;
  function Wy() {
    if (!Ot2)
      throw new Error("no time set! use setTime to define a time source");
    return Ot2();
  }
  function ee2(t) {
    Ot2 = t;
  }
  function _f(t) {
    _e2 = t;
  }
  function Fy() {
    return _e2?.();
  }
  function vf(t) {
    ve2 = t;
  }
  function Iy() {
    return ve2;
  }
  function kf(t) {
    ke2 = t;
  }
  function Vy() {
    return ke2;
  }
  function qf(t) {
    qe2 = !!t;
  }
  function Hy() {
    return qe2;
  }
  function Dy({
    defaultOutput: t,
    onEvalError: e,
    beforeEval: n2,
    beforeStart: s2,
    afterEval: r,
    getTime: o,
    transpiler: i,
    onToggle: a2,
    editPattern: u3,
    onUpdateState: p2,
    sync: h = false,
    setInterval: y3,
    clearInterval: g3,
    id: v2,
    mondo: _5 = false
  }) {
    const O2 = new en({ localScope: true }), A4 = {
      schedulerError: void 0,
      evalError: void 0,
      code: "// LOADING",
      activeCode: "// LOADING",
      pattern: void 0,
      miniLocations: [],
      widgets: [],
      pending: false,
      started: false
    }, I3 = {
      id: v2
    }, H5 = (b2) => {
      Object.assign(A4, b2), A4.isDirty = A4.code !== A4.activeCode, A4.error = A4.evalError || A4.schedulerError, p2?.(A4);
    }, P3 = {
      onTrigger: Sf({ defaultOutput: t, getTime: o }),
      getTime: o,
      onToggle: (b2) => {
        H5({ started: b2 }), qf(b2), a2?.(b2), b2 || df();
      },
      setInterval: y3,
      clearInterval: g3,
      beforeStart: s2
    }, x2 = h && typeof SharedWorker < "u" ? new bf(P3) : new hf(P3);
    kf(P3.onTrigger), _f(() => x2.cps);
    let D4 = {}, nt4 = 0, tt4;
    const Vt3 = function() {
      return D4 = {}, nt4 = 0, tt4 = void 0, q2;
    }, Je3 = (b2) => O2.evaluate(b2).compile({ log: false });
    function Ht3(b2) {
      return b2._Pattern ? b2.__pure : b2;
    }
    const Dt3 = async (b2, k6 = true) => (b2 = u3?.(b2) || b2, await x2.setPattern(b2, k6), vf(b2), b2);
    ee2(() => x2.now());
    const $e4 = () => x2.stop(), Ne4 = () => x2.start(), Le3 = () => x2.pause(), Re3 = () => x2.toggle(), St3 = (b2) => (x2.setCps(Ht3(b2)), q2), Gt3 = (b2) => (x2.setCps(Ht3(b2) / 60), q2);
    let ft2 = [];
    const We3 = function(b2) {
      return ft2.push(b2), q2;
    }, Fe4 = function(b2) {
      return tt4 = b2, q2;
    }, Ie2 = () => {
      f2.prototype.p = function(k6) {
        return typeof k6 == "string" && (k6.startsWith("_") || k6.endsWith("_")) ? q2 : (k6.includes("$") && (k6 = `${k6}${nt4}`, nt4++), D4[k6] = this, this);
      }, f2.prototype.q = function(k6) {
        return q2;
      };
      try {
        for (let k6 = 1; k6 < 10; ++k6)
          Object.defineProperty(f2.prototype, `d${k6}`, {
            get() {
              return this.p(k6);
            },
            configurable: true
          }), Object.defineProperty(f2.prototype, `p${k6}`, {
            get() {
              return this.p(k6);
            },
            configurable: true
          }), f2.prototype[`q${k6}`] = q2;
      } catch (k6) {
        console.warn("injectPatternMethods: error:", k6);
      }
      const b2 = l("cpm", function(k6, At3) {
        return At3._fast(k6 / 60 / x2.cps);
      });
      return xn({
        all: We3,
        each: Fe4,
        hush: Vt3,
        cpm: b2,
        setCps: St3,
        setcps: St3,
        setCpm: Gt3,
        setcpm: Gt3,
        compileKabel: Je3
      });
    };
    return { scheduler: x2, evaluate: async (b2, k6 = true, At3 = true) => {
      if (!b2)
        throw new Error("no code to evaluate");
      try {
        H5({ code: b2, pending: true }), await Ie2(), ee2(() => x2.now()), await n2?.({ code: b2 }), ft2 = [], At3 && Vt3(), _5 && (b2 = `mondolang\`${b2}\``);
        let { pattern: M2, meta: Tt3 } = await On(b2, i, I3);
        if (Object.keys(D4).length) {
          let X = [], ht3 = false;
          for (const [st4, Ve5] of Object.entries(D4)) {
            const Qt3 = st4.length > 1 && st4.startsWith("S");
            if (Qt3 && ht3 === false && (X = [], ht3 = true), !ht3 || ht3 && Qt3) {
              const He3 = Ve5.withState((De3) => De3.setControls({ id: st4 }));
              X.push(He3);
            }
          }
          tt4 && (X = X.map((st4) => tt4(st4))), M2 = z(...X);
        } else tt4 && (M2 = tt4(M2));
        if (ft2.length)
          for (const X of ft2)
            M2 = X(M2);
        return pe2(M2) || (M2 = q2), E2("[eval] code updated"), M2 = await Dt3(M2, k6), H5({
          miniLocations: Tt3?.miniLocations || [],
          widgets: Tt3?.widgets || [],
          activeCode: b2,
          pattern: M2,
          evalError: void 0,
          schedulerError: void 0,
          pending: false
        }), r?.({ code: b2, pattern: M2, meta: Tt3 }), M2;
      } catch (M2) {
        E2(`[eval] error: ${M2.message}`, "error"), console.error(M2), H5({ evalError: M2, pending: false }), e?.(M2);
      }
    }, start: Ne4, stop: $e4, pause: Le3, setCps: St3, setPattern: Dt3, setCode: (b2) => H5({ code: b2 }), toggle: Re3, state: A4 };
  }
  var Sf = ({ getTime: t, defaultOutput: e }) => async (n2, s2, r, o, i) => {
    try {
      (!n2.context.onTrigger || !n2.context.dominantTrigger) && await e(n2, s2, r, o, i), n2.context.onTrigger && await n2.context.onTrigger(n2, t(), o, i);
    } catch (a2) {
      zt2(a2, "getTrigger");
    }
  };
  function Gy(t) {
    return new f2((e) => [new S2(void 0, e.span, t)]);
  }
  var j2 = (t) => {
    const e = (n2) => [new S2(void 0, n2.span, t(n2.span.begin, n2.controls))];
    return new f2(e);
  };
  var qt2 = j2((t) => t % 1);
  var Se2 = qt2.toBipolar();
  var Rt2 = j2((t) => 1 - t % 1);
  var Ae2 = Rt2.toBipolar();
  var Te2 = j2((t) => Math.sin(Math.PI * 2 * t));
  var Af = Te2.fromBipolar();
  var Qy = Af._early(m(1).div(4));
  var Uy = Te2._early(m(1).div(4));
  var Tf = j2((t) => Math.floor(t * 2 % 2));
  var Xy = Tf.toBipolar();
  var Ky = N2(qt2, Rt2);
  var Yy = N2(Se2, Ae2);
  var Zy = N2(Rt2, qt2);
  var tw = N2(Ae2, Se2);
  var ew = j2(ot2);
  var Wt2 = 0;
  var Ft2 = 0;
  typeof window < "u" && document.addEventListener("mousemove", (t) => {
    Wt2 = t.clientY / document.body.clientHeight, Ft2 = t.clientX / document.body.clientWidth;
  });
  var nw = j2(() => Wt2);
  var sw = j2(() => Wt2);
  var rw = j2(() => Ft2);
  var ow = j2(() => Ft2);
  var Cf = (t) => (t |= 0, t ^= t >>> 16, t = Math.imul(t, 2246822507), t ^= t >>> 13, t = Math.imul(t, 3266489909), t ^= t >>> 16, t >>> 0);
  var xf = (t) => Math.floor(t * 536870912);
  var Bf = (t, e = 0, n2 = 0) => {
    const s2 = t >>> 0 >>> 0, r = Math.floor(t / 4294967296) >>> 0;
    let o = s2 ^ Math.imul(r ^ 2246822507, 3266489909);
    return o ^= Math.imul(e ^ 2135587861, 2654435769), o ^= Math.imul(n2 ^ 374761393, 668265261), o >>> 0;
  };
  var ne2 = (t, e = 0, n2 = 0) => Cf(Bf(t, e, n2)) / 4294967296;
  var Of = (t, e, n2 = 0) => {
    const s2 = xf(t);
    if (e === 1)
      return ne2(s2, 0, n2);
    const r = new Array(e);
    for (let o = 0; o < e; o++) r[o] = ne2(s2, o, n2);
    return r;
  };
  var Ce2 = (t) => {
    const e = t << 13 ^ t, n2 = e >> 17 ^ e;
    return n2 << 5 ^ n2;
  };
  var zf = (t) => t - Math.trunc(t);
  var Mf = (t) => Ce2(Math.trunc(zf(t / 300) * 536870912));
  var se = (t) => t % 536870912 / 536870912;
  var Pf = (t, e) => {
    if (e === 1)
      return Math.abs(se(t));
    const n2 = [];
    for (let s2 = 0; s2 < e; s2++)
      n2.push(se(t)), t = Ce2(t);
    return n2;
  };
  var Ef = (t, e) => Pf(Mf(t), e);
  var xe2 = "legacy";
  var K2 = (t, e = 1, n2 = 0) => xe2 === "legacy" ? Ef(t + n2, e) : Of(t, e, n2);
  var cw = (t = "legacy") => xe2 = t;
  var jf = (t) => qt2.range(0, t).round().segment(t);
  var iw = (t) => {
    const e = d(t).log2(0).floor().add(1);
    return Jf(t, e);
  };
  var Jf = (t, e = 16) => {
    e = d(e);
    const n2 = jf(e).mul(-1).add(e.sub(1));
    return d(t).segment(e).brshift(n2).band(C2(1));
  };
  var uw = (t) => {
    const e = d(t).log2(0).floor().add(1);
    return $f(t, e);
  };
  var $f = (t, e = 16) => d(t).withValue((n2) => (s2) => {
    const r = [];
    for (let o = s2 - 1; o >= 0; o--)
      r.push(n2 >> o & 1);
    return r;
  }).appLeft(d(e));
  var aw = (t) => j2((e) => (n2) => K2(e, n2).map(Math.abs)).appLeft(d(t));
  var Nf = (t) => j2((e, n2) => {
    const r = K2(e.floor().add(0.5), t, n2.randSeed).map((i, a2) => [i, a2]).sort((i, a2) => (i[0] > a2[0]) - (i[0] < a2[0])).map((i) => i[1]), o = e.cyclePos().mul(t).floor() % t;
    return r[o];
  })._segment(t);
  var Be2 = (t, e, n2) => {
    const s2 = [...Array(e).keys()].map((r) => n2.zoom(m(r).div(e), m(r + 1).div(e)));
    return t.fmap((r) => s2[r].repeatCycles(e)._fast(e)).innerJoin();
  };
  var lw = l("shuffle", (t, e) => Be2(Nf(t), t, e));
  var pw = l("scramble", (t, e) => Be2(ze2(t)._segment(t), t, e));
  var Lf = (t, e) => new f2((n2) => {
    let { randSeed: s2, ...r } = n2.controls;
    return s2 = t(s2), e.query(n2.setControls({ ...r, randSeed: s2 }));
  }, e._steps);
  var fw = l("seed", (t, e) => Lf(() => t, e));
  var W2 = j2((t, e) => K2(t, 1, e.randSeed));
  var hw = W2.toBipolar();
  var Oe2 = (t) => W2.fmap((e) => e < t);
  var dw = (t) => d(t).fmap(Oe2).innerJoin();
  var mw = Oe2(0.5);
  var ze2 = (t) => W2.fmap((e) => Math.trunc(e * t));
  var yw = (t) => d(t).fmap(ze2).innerJoin();
  var Me2 = (t, e) => (e = e.map(d), e.length == 0 ? q2 : t.range(0, e.length).fmap((n2) => {
    const s2 = Math.min(Math.max(Math.floor(n2), 0), e.length - 1);
    return e[s2];
  }));
  var It2 = (t, e) => Me2(t, e).outerJoin();
  var Pe2 = (t, e) => Me2(t, e).innerJoin();
  var Rf = (...t) => It2(W2, t);
  var ww = (...t) => Pe2(W2, t);
  var gw = Rf;
  f2.prototype.choose = function(...t) {
    return It2(this, t);
  };
  f2.prototype.choose2 = function(...t) {
    return It2(this.fromBipolar(), t);
  };
  var Wf = (...t) => Pe2(W2.segment(1), t);
  var bw = Wf;
  var Ee2 = function(t, ...e) {
    const n2 = e.map((a2) => d(a2[0])), s2 = [];
    let r = C2(0);
    for (const a2 of e)
      r = r.add(a2[1]), s2.push(r);
    const o = En(s2), i = function(a2) {
      const u3 = r.mul(a2);
      return o.fmap((p2) => (h) => n2[p2.findIndex((y3) => y3 > h, p2)]).appLeft(u3);
    };
    return t.bind(i);
  };
  var Ff = (...t) => Ee2(...t).outerJoin();
  var _w = (...t) => Ff(W2, ...t);
  var If = (...t) => Ee2(W2.segment(1), ...t).innerJoin();
  var vw = If;
  function Vf(t, e = 0) {
    let n2 = Math.floor(t), s2 = n2 + 1;
    const r = (p2) => 6 * p2 ** 5 - 15 * p2 ** 4 + 10 * p2 ** 3, o = (p2) => (h) => (y3) => h + r(p2) * (y3 - h), i = K2(n2, 1, e), a2 = K2(s2, 1, e);
    return o(t - n2)(i)(a2);
  }
  function Hf(t, e = 0) {
    const n2 = Math.floor(t), s2 = n2 + 1, r = K2(n2, 1, e), o = K2(s2, 1, e), i = r + o, a2 = (t - n2) / (s2 - n2);
    return ((p2, h, y3) => p2 + y3 * (h - p2))(r, i, a2) / 2;
  }
  var kw = j2((t, e) => Vf(t, e.randSeed));
  var qw = j2((t, e) => Hf(t, e.randSeed));
  var Sw = l(
    "degradeByWith",
    (t, e, n2) => n2.fmap((s2) => (r) => s2).appLeft(t.filterValues((s2) => s2 > e)),
    true,
    true
  );
  var Aw = l(
    "degradeBy",
    function(t, e) {
      return e._degradeByWith(W2, t);
    },
    true,
    true
  );
  var Tw = l("degrade", (t) => t._degradeBy(0.5), true, true);
  var Cw = l(
    "undegradeBy",
    function(t, e) {
      return e._degradeByWith(
        W2.fmap((n2) => 1 - n2),
        t
      );
    },
    true,
    true
  );
  var xw = l("undegrade", (t) => t._undegradeBy(0.5), true, true);
  var Bw = l("sometimesBy", function(t, e, n2) {
    return d(t).fmap((s2) => z(n2._degradeBy(s2), e(n2._undegradeBy(1 - s2)))).innerJoin();
  });
  var Ow = l("sometimes", function(t, e) {
    return e._sometimesBy(0.5, t);
  });
  var zw = l("someCyclesBy", function(t, e, n2) {
    return d(t).fmap(
      (s2) => z(
        n2._degradeByWith(W2._segment(1), s2),
        e(n2._degradeByWith(W2.fmap((r) => 1 - r)._segment(1), 1 - s2))
      )
    ).innerJoin();
  });
  var Mw = l("someCycles", function(t, e) {
    return e._someCyclesBy(0.5, t);
  });
  var Pw = l("often", function(t, e) {
    return e.sometimesBy(0.75, t);
  });
  var Ew = l("rarely", function(t, e) {
    return e.sometimesBy(0.25, t);
  });
  var jw = l("almostNever", function(t, e) {
    return e.sometimesBy(0.1, t);
  });
  var Jw = l("almostAlways", function(t, e) {
    return e.sometimesBy(0.9, t);
  });
  var $w = l("never", function(t, e) {
    return e;
  });
  var Nw = l("always", function(t, e) {
    return t(e);
  });
  function je2(t) {
    Array.isArray(t) === false && (t = [t]);
    const e = qn();
    return t.every((n2) => {
      const s2 = kn.get(n2) ?? n2;
      return e[s2];
    });
  }
  var Lw = l("whenKey", function(t, e, n2) {
    return n2.when(je2(t), e);
  });
  var Rw = l("keyDown", function(t) {
    return t.fmap(je2);
  });
  var Ww = new f2(function(t) {
    return [new S2(void 0, t.span, t.span.duration)];
  });
  var Df = new f2(function(t) {
    return [new S2(void 0, t.span, m(1).div(t.span.duration))];
  });
  var Fw = Df;
  var Iw = new f2(function(t) {
    const e = m(1).div(t.span.duration);
    return [new S2(void 0, t.span, Math.log(e) / Math.log(2) + 1)];
  });
  var wt2;
  try {
    wt2 = window?.speechSynthesis;
  } catch {
    console.warn("cannot use window: not in browser?");
  }
  var re2 = wt2?.getVoices();
  function Gf(t, e, n2) {
    wt2.cancel();
    const s2 = new SpeechSynthesisUtterance(t);
    s2.lang = e, re2 = wt2.getVoices();
    const r = re2.filter((o) => o.lang.includes(e));
    typeof n2 == "number" ? s2.voice = r[n2 % r.length] : typeof n2 == "string" && (s2.voice = r.find((o) => o.name === o)), speechSynthesis.speak(s2);
  }
  var Vw = l("speak", function(t, e, n2) {
    return n2.onTrigger((s2) => {
      Gf(s2.value, t, e);
    });
  });
  var Hw = function(t, e = {}) {
    const n2 = document.getElementById("code"), s2 = "background-image:url(" + t + ");background-size:contain;";
    n2.style = s2;
    const { className: r } = n2, o = (u3, p2) => {
      ({
        style: () => n2.style = s2 + ";" + p2,
        className: () => n2.className = p2 + " " + r
      })[u3]();
    }, i = Object.entries(e).filter(([u3, p2]) => typeof p2 == "function");
    Object.entries(e).filter(([u3, p2]) => typeof p2 == "string").forEach(([u3, p2]) => o(u3, p2)), i.length;
  };
  var Dw = () => {
    const t = document.getElementById("code");
    t && (t.style = "");
  };
  E2("\u{1F300} @strudel/core loaded \u{1F300}");
  globalThis._strudelLoaded && console.warn(
    `@strudel/core was loaded more than once...
This might happen when you have multiple versions of strudel installed. 
Please check with "npm ls @strudel/core".`
  );
  globalThis._strudelLoaded = true;

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/webaudio/dist/index.mjs
  var dist_exports2 = {};
  __export(dist_exports2, {
    DEFAULT_MAX_POLYPHONY: () => $t3,
    Warpmode: () => gt3,
    aliasBank: () => _o2,
    analysers: () => ne3,
    analysersData: () => Le2,
    applyFM: () => je3,
    applyGainCurve: () => ie3,
    applyParameterModulators: () => zt3,
    cleanupOnEnd: () => kn2,
    connectBusModulator: () => An2,
    connectEnvelope: () => Dn2,
    connectLFO: () => On2,
    connectToDestination: () => lc2,
    createFilter: () => xn2,
    distortionAlgorithms: () => Et3,
    dough: () => mc2,
    doughTrigger: () => Gc2,
    doughsamples: () => le2,
    drawFrequencyScope: () => Ve4,
    drawTimeScope: () => Ue4,
    drywet: () => zn2,
    dspWorklet: () => Io2,
    effectSend: () => Ue3,
    errorLogger: () => ct3,
    fetchSampleMap: () => ce4,
    gainNode: () => T2,
    getADSRValues: () => $3,
    getAnalyserById: () => Ko2,
    getAnalyzerData: () => ic2,
    getAudioContext: () => z2,
    getAudioContextCurrentTime: () => jo2,
    getAudioDevices: () => Vo2,
    getCachedBuffer: () => Eo2,
    getCompressor: () => Ln2,
    getDefaultValue: () => U3,
    getDistortion: () => Cn2,
    getDistortionAlgorithm: () => vo2,
    getEnvelope: () => Vn2,
    getFrequencyFromValue: () => Xe3,
    getLfo: () => Fe2,
    getLoadedBuffer: () => Oo2,
    getOscillator: () => Co2,
    getParamADSR: () => _2,
    getParamLfo: () => jt3,
    getPitchEnvelope: () => He2,
    getSampleBuffer: () => $n2,
    getSampleBufferSource: () => eo2,
    getSampleInfo: () => _n2,
    getSound: () => Me3,
    getSuperdoughAudioController: () => Zt3,
    getVibratoOscillator: () => Te3,
    getWorklet: () => q3,
    getZZFX: () => Po2,
    initAudio: () => Ro2,
    initAudioOnFirstClick: () => sc2,
    loadBuffer: () => dt3,
    loadWorklets: () => zo2,
    logger: () => j3,
    maxPolyphony: () => en3,
    multiChannelOrbits: () => tn2,
    noises: () => Ut3,
    onTriggerSample: () => so2,
    onTriggerSynth: () => Zo2,
    onceEnded: () => ue3,
    processSampleMap: () => no2,
    registerSampleSource: () => io2,
    registerSamplesPrefix: () => Do2,
    registerSound: () => ce3,
    registerSynthSounds: () => uc2,
    registerWaveTable: () => _t3,
    registerWorklet: () => ac2,
    registerZZFXSounds: () => hc2,
    releaseAudioNode: () => Y3,
    renderPatternAudio: () => qe3,
    resetDefaultValues: () => xo2,
    resetDefaults: () => tc2,
    resetGlobalEffects: () => rc2,
    resetLoadedSounds: () => cc2,
    resetSeenKeys: () => ho2,
    reverseBuffer: () => to2,
    samples: () => ao2,
    scheduleAtTime: () => Qo2,
    setAudioContext: () => Uo2,
    setDefault: () => ec2,
    setDefaultAudioContext: () => pn2,
    setDefaultValue: () => on2,
    setDefaultValues: () => nc2,
    setGainCurve: () => qo2,
    setLogger: () => Bo2,
    setMaxPolyphony: () => Wo2,
    setMultiChannelOrbits: () => fo2,
    setSuperdoughAudioController: () => dc2,
    setVersionDefaults: () => oc2,
    soundAlias: () => $o2,
    soundMap: () => ae2,
    superdough: () => No2,
    superdoughTrigger: () => pc2,
    tables: () => Ao2,
    waveformN: () => Fo2,
    webAudioTimeout: () => pe3,
    webaudioOutput: () => De2,
    webaudioRepl: () => Fe3
  });

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/nanostores/clean-stores/index.js
  var clean = /* @__PURE__ */ Symbol("clean");

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/nanostores/atom/index.js
  var listenerQueue = [];
  var lqIndex = 0;
  var QUEUE_ITEMS_PER_LISTENER = 4;
  var epoch = 0;
  var atom = (initialValue) => {
    let listeners = [];
    let $atom = {
      get() {
        if (!$atom.lc) {
          $atom.listen(() => {
          })();
        }
        return $atom.value;
      },
      lc: 0,
      listen(listener) {
        $atom.lc = listeners.push(listener);
        return () => {
          for (let i = lqIndex + QUEUE_ITEMS_PER_LISTENER; i < listenerQueue.length; ) {
            if (listenerQueue[i] === listener) {
              listenerQueue.splice(i, QUEUE_ITEMS_PER_LISTENER);
            } else {
              i += QUEUE_ITEMS_PER_LISTENER;
            }
          }
          let index = listeners.indexOf(listener);
          if (~index) {
            listeners.splice(index, 1);
            if (!--$atom.lc) $atom.off();
          }
        };
      },
      notify(oldValue, changedKey) {
        epoch++;
        let runListenerQueue = !listenerQueue.length;
        for (let listener of listeners) {
          listenerQueue.push(
            listener,
            $atom.value,
            oldValue,
            changedKey
          );
        }
        if (runListenerQueue) {
          for (lqIndex = 0; lqIndex < listenerQueue.length; lqIndex += QUEUE_ITEMS_PER_LISTENER) {
            listenerQueue[lqIndex](
              listenerQueue[lqIndex + 1],
              listenerQueue[lqIndex + 2],
              listenerQueue[lqIndex + 3]
            );
          }
          listenerQueue.length = 0;
        }
      },
      /* It will be called on last listener unsubscribing.
         We will redefine it in onMount and onStop. */
      off() {
      },
      set(newValue) {
        let oldValue = $atom.value;
        if (oldValue !== newValue) {
          $atom.value = newValue;
          $atom.notify(oldValue);
        }
      },
      subscribe(listener) {
        let unbind = $atom.listen(listener);
        listener($atom.value);
        return unbind;
      },
      value: initialValue
    };
    if (true) {
      $atom[clean] = () => {
        listeners = [];
        $atom.lc = 0;
        $atom.off();
      };
    }
    return $atom;
  };

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/nanostores/map/index.js
  var map = (initial = {}) => {
    let $map = atom(initial);
    $map.setKey = function(key, value) {
      let oldMap = $map.value;
      if (typeof value === "undefined" && key in $map.value) {
        $map.value = { ...$map.value };
        delete $map.value[key];
        $map.notify(oldMap, key);
      } else if ($map.value[key] !== value) {
        $map.value = {
          ...$map.value,
          [key]: value
        };
        $map.notify(oldMap, key);
      }
    };
    return $map;
  };

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/superdough/dist/index.mjs
  if (typeof DelayNode < "u") {
    class e extends DelayNode {
      constructor(n2, o, a2, c3) {
        return super(n2), o = Math.abs(o), this.delayTime.value = a2, this.feedbackGain = n2.createGain(), this.feedbackGain.gain.value = Math.min(Math.abs(c3), 0.995), this.feedback = this.feedbackGain.gain, this.delayGain = n2.createGain(), this.delayGain.gain.value = o, this.connect(this.feedbackGain), this.connect(this.delayGain), this.feedbackGain.connect(this), this.connect = (s2) => this.delayGain.connect(s2), this;
      }
      start(n2) {
        this.delayGain.gain.setValueAtTime(this.delayGain.gain.value, n2 + this.delayTime.value);
      }
    }
    BaseAudioContext.prototype.createFeedbackDelay = function(t, n2, o) {
      return new e(this, t, n2, o);
    };
  }
  var ze3;
  var pn2 = () => (ze3 = new AudioContext(), ze3);
  var Uo2 = (e) => (ze3 = e, ze3);
  var z2 = () => ze3 || pn2();
  function jo2() {
    return z2().currentTime;
  }
  var wt3 = (e) => console.log(e);
  function ct3(e, t = "superdough") {
    console.error(e), j3(`[${t}] error: ${e.message}`);
  }
  var j3 = (...e) => wt3(...e);
  var Bo2 = (e) => {
    wt3 = e;
  };
  var $e2 = {};
  function Ft3(e, t) {
    const n2 = z2();
    if ($e2[e])
      return $e2[e];
    const o = 2 * n2.sampleRate, a2 = n2.createBuffer(1, o, n2.sampleRate), c3 = a2.getChannelData(0);
    let s2 = 0, d2, l2, i, p2, r, h, u3;
    d2 = l2 = i = p2 = r = h = u3 = 0;
    for (let m3 = 0; m3 < o; m3++)
      if (e === "white")
        c3[m3] = Math.random() * 2 - 1;
      else if (e === "brown") {
        let G4 = Math.random() * 2 - 1;
        c3[m3] = (s2 + 0.02 * G4) / 1.02, s2 = c3[m3];
      } else if (e === "pink") {
        let G4 = Math.random() * 2 - 1;
        d2 = 0.99886 * d2 + G4 * 0.0555179, l2 = 0.99332 * l2 + G4 * 0.0750759, i = 0.969 * i + G4 * 0.153852, p2 = 0.8665 * p2 + G4 * 0.3104856, r = 0.55 * r + G4 * 0.5329522, h = -0.7616 * h - G4 * 0.016898, c3[m3] = d2 + l2 + i + p2 + r + h + u3 + G4 * 0.5362, c3[m3] *= 0.11, u3 = G4 * 0.115926;
      } else if (e === "crackle") {
        const G4 = t * 0.01;
        Math.random() < G4 ? c3[m3] = Math.random() * 2 - 1 : c3[m3] = 0;
      }
    return e !== "crackle" && ($e2[e] = a2), a2;
  }
  function at3(e = "white", t, n2 = 0.02) {
    const a2 = z2().createBufferSource();
    return a2.buffer = Ft3(e, n2), a2.loop = true, a2.start(t), {
      node: a2,
      stop: (c3) => a2.stop(c3)
    };
  }
  function un2(e, t, n2) {
    const o = at3("pink", n2), a2 = zn2(e, o.node, t);
    return ue3(o.node, () => {
      Y3(o.node);
    }), {
      node: a2.node,
      stop: (c3) => o?.stop(c3),
      teardown: a2.teardown
    };
  }
  var st2 = /* @__PURE__ */ new Map();
  var ut3 = /* @__PURE__ */ Symbol("nodePoolKey");
  var hn2 = (e) => !!e[ut3];
  var Ct3 = (e) => e.context?.currentTime ?? 0;
  var mn2 = (e) => {
    const t = /* @__PURE__ */ new Set();
    e.parameters?.forEach((a2) => t.add(a2));
    const n2 = /* @__PURE__ */ new Set();
    let o = e;
    for (; o !== Object.prototype; ) {
      for (const a2 of Object.getOwnPropertyNames(o)) {
        if (n2.has(a2)) continue;
        n2.add(a2);
        const c3 = e[a2];
        c3 instanceof AudioParam && t.add(c3);
      }
      o = Object.getPrototypeOf(o);
    }
    return t;
  };
  var ht2 = (e) => {
    if (e.disconnect(), e instanceof AudioScheduledSourceNode)
      return;
    const t = e[ut3];
    if (t == null) return;
    const n2 = Ct3(e);
    mn2(e).forEach((a2) => a2.cancelScheduledValues(n2));
    const o = st2.get(t) ?? [];
    o.push(new WeakRef(e)), st2.set(t, o);
  };
  var Gn2 = (e) => {
    if (!(e instanceof AudioWorkletNode)) return true;
    const t = Ct3(e), n2 = e?.parameters?.get("end").value ?? 0;
    return t < n2 + 0.45;
  };
  var we3 = (e, t) => {
    const n2 = st2.get(e) ?? [];
    let o, a2 = false;
    for (; n2.length; )
      if (o = n2.pop()?.deref(), o != null && Gn2(o)) {
        a2 = true;
        break;
      }
    return a2 || (o = t()), o[ut3] = e, o;
  };
  var Xn2 = (e) => {
    if (typeof e != "string")
      return [];
    const [t, n2 = "", o] = e.match(/^([a-gA-G])([#bsf]*)(-?[0-9]*)$/)?.slice(1) || [];
    return t ? [t, n2, o ? Number(o) : void 0] : [];
  };
  var yn2 = { c: 0, d: 2, e: 4, f: 5, g: 7, a: 9, b: 11 };
  var bn2 = { "#": 1, b: -1, s: 1, f: -1 };
  var Zn2 = (e) => e?.split("").reduce((t, n2) => t + bn2[n2], 0) || 0;
  var Be3 = (e, t = 3) => {
    const [n2, o, a2 = t] = Xn2(e);
    if (!n2)
      throw new Error('not a note: "' + e + '"');
    const c3 = yn2[n2.toLowerCase()], s2 = Zn2(o);
    return (Number(a2) + 1) * 12 + c3 + s2;
  };
  var kt3 = (e) => Math.pow(2, (e - 69) / 12) * 440;
  var se2 = (e, t, n2) => Math.min(Math.max(e, t), n2);
  var Wn2 = (e) => 12 * Math.log(e / 440) / Math.LN2 + 69;
  var fn2 = (e, t) => {
    if (typeof e != "object")
      throw new Error("valueToMidi: expected object value");
    let { freq: n2, note: o } = e;
    return typeof n2 == "number" ? Wn2(n2) : typeof o == "string" ? Be3(o) : typeof o == "number" ? o : t;
  };
  function re3(e, t = 0, n2) {
    return isNaN(Number(e)) ? (!n2 && j3(`"${e}" is not a number, falling back to ${t}`, "warning"), t) : e;
  }
  var Pt3 = (e, t) => (e % t + t) % t;
  var Vt2 = (e, t) => Pt3(Math.round(re3(e, 0)), t);
  function Lt3(e, t) {
    return e / t;
  }
  function It3(e, t) {
    const { s: n2, n: o = 0 } = e;
    let a2 = fn2(e, 36), c3 = a2 - 36, s2, d2 = 0;
    if (Array.isArray(t))
      d2 = Vt2(o, t.length), s2 = t[d2];
    else {
      const i = (r) => Be3(r) - a2, p2 = Object.keys(t).filter((r) => !r.startsWith("_")).reduce(
        (r, h, u3) => !r || Math.abs(i(h)) < Math.abs(i(r)) ? h : r,
        null
      );
      c3 = -i(p2), d2 = Vt2(o, t[p2].length), s2 = t[p2][d2];
    }
    const l2 = `${n2}:${d2}`;
    return { transpose: c3, url: s2, index: d2, midi: a2, label: l2 };
  }
  var et3 = (e, t) => Object.fromEntries(Object.entries(t).map(([n2, o]) => [n2, e[o]]));
  var Jt3 = (e) => {
    try {
      return new URL(".", new URL(e)).href.replace(/\/$/, "");
    } catch {
      return e.split("/").slice(0, -1).join("/");
    }
  };
  var Ut3 = ["pink", "white", "brown", "crackle"];
  function T2(e) {
    const t = z2().createGain();
    return t.gain.value = e, t;
  }
  function Ue3(e, t, n2) {
    const o = T2(n2);
    return e.connect(o), o.connect(t), o;
  }
  var xt3 = (e, t, n2, o) => o - n2 === 0 ? 0 : (t - e) / (o - n2);
  function q3(e, t, n2, o) {
    const a2 = new AudioWorkletNode(e, t, o);
    return Object.entries(n2).forEach(([c3, s2]) => {
      s2 !== void 0 && (a2.parameters.get(c3).value = s2);
    }), a2;
  }
  var _2 = (e, t, n2, o, a2, c3, s2, d2, l2, i = "exponential") => {
    t = re3(t), n2 = re3(n2), o = re3(o), a2 = re3(a2);
    const p2 = i === "exponential" ? "exponentialRampToValueAtTime" : "linearRampToValueAtTime";
    i === "exponential" && (c3 = c3 === 0 ? 1e-3 : c3, s2 = s2 === 0 ? 1e-3 : s2);
    const r = s2 - c3, h = c3 + o * r, u3 = l2 - d2, m3 = (G4) => {
      let b2;
      return t > G4 ? b2 = G4 * xt3(c3, s2, 0, t) + c3 : b2 = (G4 - t) * xt3(s2, h, 0, n2) + s2, i === "exponential" && (b2 = b2 || 1e-3), b2;
    };
    e.setValueAtTime(c3, d2), t > u3 ? e[p2](m3(u3), l2) : t + n2 > u3 ? (e[p2](m3(t), d2 + t), e[p2](m3(u3), l2)) : (e[p2](m3(t), d2 + t), e[p2](m3(t + n2), d2 + t + n2), e.setValueAtTime(h, l2)), e[p2](c3, l2 + a2);
  };
  function Mn2(e) {
    return typeof e == "number" ? e % 5 : { tri: 0, triangle: 0, sine: 1, ramp: 2, saw: 3, square: 4 }[e] ?? 0;
  }
  function Vn2(e, t = {}) {
    return q3(e, "envelope-processor", t);
  }
  function Fe2(e, t = {}) {
    const {
      shape: n2 = 0,
      begin: o = 0,
      end: a2 = 0,
      time: c3,
      depth: s2 = 1,
      dcoffset: d2 = -0.5,
      frequency: l2 = 1,
      skew: i = 0.5,
      phaseoffset: p2 = 0,
      curve: r = 1,
      min: h,
      max: u3,
      ...m3
    } = t, G4 = {
      begin: o,
      end: a2,
      time: c3 ?? o,
      depth: s2,
      dcoffset: d2,
      frequency: l2,
      skew: i,
      phaseoffset: p2,
      curve: r,
      shape: Mn2(n2),
      min: h ?? d2 * s2,
      max: u3 ?? d2 * s2 + s2,
      ...m3
    };
    return q3(e, "lfo-processor", G4);
  }
  function Ln2(e, t, n2, o, a2, c3) {
    const s2 = we3("compressor", () => new DynamicsCompressorNode(e, {}));
    return Object.entries({
      threshold: t ?? -3,
      ratio: n2 ?? 10,
      knee: o ?? 10,
      attack: a2 ?? 5e-3,
      release: c3 ?? 0.05
    }).forEach(([l2, i]) => {
      s2[l2].value = i;
    }), s2;
  }
  var $3 = (e, t = "linear", n2) => {
    const [s2, d2, l2, i] = e;
    if (s2 == null && d2 == null && l2 == null && i == null)
      return n2 ?? [1e-3, 1e-3, 1, 0.01];
    const p2 = l2 ?? (s2 != null && d2 == null || s2 == null && d2 == null ? 1 : 1e-3);
    return [Math.max(s2 ?? 0, 1e-3), Math.max(d2 ?? 0, 1e-3), Math.min(p2, 1), Math.max(i ?? 0, 0.01)];
  };
  function jt3(e, t, n2, o, a2) {
    let { defaultDepth: c3 = 1, depth: s2, dcoffset: d2, ...l2 } = a2;
    s2 == null && (s2 = Object.values(l2).some((r) => r != null) ? c3 : 0);
    let i;
    return s2 && (i = Fe2(e, {
      begin: n2,
      end: o,
      depth: s2,
      dcoffset: d2,
      ...l2
    }), i.connect(t)), i;
  }
  function zt3(e, t, n2, o, a2, c3) {
    let { amount: s2, offset: d2, defaultAmount: l2 = 1, curve: i = "linear", values: p2, holdEnd: r, defaultValues: h } = a2;
    s2 == null && (s2 = p2.some((y3) => y3 != null) ? l2 : 0);
    const u3 = d2 ?? 0, m3 = s2 + u3;
    if (Math.abs(m3 - u3)) {
      const [f4, y3, M2, Z5] = $3(p2, i, h);
      _2(t, f4, y3, M2, Z5, u3, m3, n2, r, i);
    }
    return jt3(e, t, n2, o, c3);
  }
  function xn2(e, t, n2, o, a2, c3) {
    let {
      frequency: s2,
      anchor: d2,
      env: l2,
      type: i,
      model: p2,
      q: r = 1,
      drive: h = 0.69,
      depth: u3,
      depthfrequency: m3,
      dcoffset: G4 = -0.5,
      skew: b2,
      shape: f4,
      rate: y3,
      sync: M2
    } = o, Z5, W6;
    p2 === "ladder" ? (W6 = q3(e, "ladder-processor", { frequency: s2, q: r, drive: h }), Z5 = W6.parameters.get("frequency")) : (W6 = we3("filter", () => e.createBiquadFilter()), W6.type = i, Object.entries({ Q: r, frequency: s2 }).forEach(([O2, w5]) => {
      W6[O2].value = w5;
    }), Z5 = W6.frequency);
    const S5 = [o.attack, o.decay, o.sustain, o.release], [Q4, F4, N5, g3] = $3(S5, "exponential", [5e-3, 0.14, 0, 0.1]);
    if ([...S5, l2].some((k6) => k6 !== void 0)) {
      l2 = re3(l2, 1, true), d2 = re3(d2, 0, true);
      const k6 = Math.abs(l2), O2 = k6 * d2;
      let w5 = se2(2 ** -O2 * s2, 0, 2e4), E4 = se2(2 ** (k6 - O2) * s2, 0, 2e4);
      l2 < 0 && ([w5, E4] = [E4, w5]), _2(Z5, Q4, F4, N5, g3, w5, E4, t, n2, "exponential");
    }
    M2 != null && (y3 = a2 * M2);
    const K4 = [u3, m3, b2, f4, y3].some((k6) => k6 !== void 0);
    let I3;
    if (K4) {
      u3 = u3 ?? 1;
      const k6 = c3 / a2, w5 = {
        depth: m3 ?? (u3 ?? 1) * s2,
        dcoffset: G4,
        skew: b2,
        shape: f4,
        frequency: y3 ?? a2,
        min: -s2 + 30,
        max: 2e4 - s2,
        time: k6,
        curve: 1
      };
      I3 = jt3(e, Z5, t, n2, w5);
    }
    return { filter: W6, lfo: I3 };
  }
  var Rt3 = (e) => e < 0.5 ? 1 : 1 - (e - 0.5) / 0.5;
  function zn2(e, t, n2 = 0) {
    const o = z2();
    if (!n2)
      return e;
    let a2 = o.createGain(), c3 = o.createGain();
    e.connect(a2), t.connect(c3), a2.gain.value = Rt3(n2), c3.gain.value = Rt3(1 - n2);
    let s2 = o.createGain();
    return a2.connect(s2), c3.connect(s2), {
      node: s2,
      teardown: () => {
        Y3(a2), Y3(c3), e.disconnect(a2), t.disconnect(c3);
      }
    };
  }
  var Rn2 = ["linear", "exponential"];
  function He2(e, t, n2, o) {
    if ((t.pattack ?? t.pdecay ?? t.psustain ?? t.prelease ?? t.penv) === void 0)
      return;
    const c3 = re3(t.penv, 1, true), s2 = Rn2[t.pcurve ?? 0];
    let [d2, l2, i, p2] = $3(
      [t.pattack, t.pdecay, t.psustain, t.prelease],
      s2,
      [0.2, 1e-3, 1, 1e-3]
    ), r = t.panchor ?? i;
    const h = c3 * 100, u3 = 0 - h * r, m3 = h - h * r;
    _2(e, d2, l2, i, p2, u3, m3, n2, o, s2);
  }
  function Te3(e, t, n2) {
    const { vibmod: o = 0.5, vib: a2 } = t;
    let c3;
    if (a2 > 0) {
      c3 = z2().createOscillator(), c3.frequency.value = a2;
      const s2 = z2().createGain();
      return s2.gain.value = o * 100, c3.connect(s2), s2.connect(e), ue3(c3, () => {
        Y3(s2), Y3(c3);
      }), c3.start(n2), { stop: (d2) => c3.stop(d2), nodes: { vib: [c3], vib_gain: [s2] } };
    }
  }
  function Qo2(e, t, n2 = z2()) {
    const o = n2.currentTime;
    pe3(n2, e, o, t);
  }
  function pe3(e, t, n2, o) {
    const a2 = new ConstantSourceNode(e), c3 = T2(0);
    return c3.connect(e.destination), a2.connect(c3), ue3(a2, () => {
      Y3(c3), Y3(a2), t();
    }), a2.start(n2), a2.stop(o), a2;
  }
  var Yn2 = (e, t = "sine") => {
    const n2 = z2();
    let o;
    return Ut3.includes(t) ? (o = n2.createBufferSource(), o.buffer = Ft3(t, 2), o.loop = true) : (o = n2.createOscillator(), o.type = t, o.frequency.value = e), o.start(), o;
  };
  var Sn2 = (e, t, n2 = "sine") => {
    const a2 = e.value * t;
    return { osc: Yn2(a2, n2), freq: a2 };
  };
  function je3(e, t, n2) {
    const o = z2(), a2 = [], c3 = {}, s2 = {};
    for (let d2 = 1; d2 <= 8; d2++)
      for (let l2 = 0; l2 <= 8; l2++) {
        let i;
        d2 === l2 + 1 ? i = `fmi${d2 === 1 ? "" : d2}` : i = `fmi${d2}${l2}`;
        const p2 = t[i];
        if (!p2) continue;
        let r = [];
        for (let [h, u3] of [
          [true, d2],
          // source
          [false, l2]
          // target
        ]) {
          if (u3 === 0) {
            r.push(e);
            continue;
          }
          if (!c3[u3]) {
            const W6 = u3 === 1 ? "" : u3, { osc: S5, freq: Q4 } = Sn2(e, t[`fmh${W6}`] ?? 1, t[`fmwave${W6}`] ?? "sine");
            a2.push(S5);
            const F4 = [S5], N5 = ["attack", "decay", "sustain", "release"].map((C6) => t[`fm${C6}${W6}`]);
            let g3 = S5;
            if (N5.some((C6) => C6 !== void 0)) {
              const C6 = o.createGain(), [K4, I3, k6, O2] = $3(N5), w5 = n2 + t.duration, E4 = t[`fmenv${W6}`] ?? "exp";
              _2(
                C6.gain,
                K4,
                I3,
                k6,
                O2,
                0,
                1,
                n2,
                w5,
                E4 === "exp" ? "exponential" : "linear"
              ), F4.push(C6), g3 = S5.connect(C6);
            }
            c3[u3] = { input: S5.frequency, output: g3, freq: Q4, osc: S5, toCleanup: F4 }, s2[`fm_${u3}`] = [S5];
          }
          const { input: m3, output: G4, freq: b2, osc: f4, toCleanup: y3 } = c3[u3], M2 = T2(p2), Z5 = T2(b2);
          r.push(h ? G4.connect(M2).connect(Z5) : m3), kn2(f4, [...y3, M2, Z5]), s2[`fm_${u3}_gain`] = [M2];
        }
        if (!r[1]) {
          j3(
            `[superdough] control ${i} failed to connect FM ${d2} to target ${l2} due to missing frequency parameter (likely because fm${l2} is noise)`,
            "warning"
          );
          continue;
        }
        r[0].connect(r[1]);
      }
    return {
      nodes: s2,
      stop: (d2) => a2.forEach((l2) => l2?.stop(d2))
    };
  }
  var Bt3 = (e) => e / (1 + e);
  var Kn2 = (e, t) => (e % t + t) % t;
  var gn2 = (e, t) => (1 + t) * e / (1 + t * Math.abs(e));
  var Ve2 = (e, t) => Math.tanh(e * (1 + t));
  var Nn2 = (e, t) => se2((1 + t) * e, -1, 1);
  var Qt2 = (e, t) => {
    let n2 = (1 + 0.5 * t) * e;
    const o = Kn2(n2 + 1, 4);
    return 1 - Math.abs(o - 2);
  };
  var Hn2 = (e, t) => Math.sin(Math.PI / 2 * Qt2(e, t));
  var Tn2 = (e, t) => {
    const n2 = Bt3(Math.log1p(t)), o = (e - n2 / 3 * e * e * e) / (1 - n2 / 3);
    return Ve2(o, t);
  };
  var vt3 = (e, t, n2 = false) => {
    const o = 1 + 2 * t, c3 = 0.07 * Bt3(Math.log1p(t)), s2 = Ve2(e + c3, 2 * t), d2 = Ve2(n2 ? c3 : -e + c3, 2 * t), l2 = s2 - d2, i = 1 / Math.cosh(o * c3), p2 = i * i, r = Math.max(1e-8, (n2 ? 1 : 2) * o * p2);
    return Ve2(l2 / r, t);
  };
  var wn2 = (e, t) => vt3(e, t, true);
  var Fn2 = (e, t) => {
    const n2 = 10 * Math.log1p(t);
    let o = 1, a2 = e, c3, s2 = 0;
    for (let d2 = 1; d2 < 64; d2++) {
      if (d2 < 2) {
        s2 += d2 == 0 ? o : a2;
        continue;
      }
      c3 = 2 * e * o - a2, a2 = o, o = c3, d2 % 2 === 0 && (s2 += Math.min(1.3 * n2 / d2, 2) * c3);
    }
    return Ve2(s2, n2 / 20);
  };
  var Et3 = {
    scurve: gn2,
    soft: Ve2,
    hard: Nn2,
    cubic: Tn2,
    diode: vt3,
    asym: wn2,
    fold: Qt2,
    sinefold: Hn2,
    chebyshev: Fn2
  };
  var ge3 = Object.freeze(Object.keys(Et3));
  var vo2 = (e) => {
    let t = e;
    typeof e == "string" && (t = ge3.indexOf(e), t === -1 && (j3(`[superdough] Could not find waveshaping algorithm ${e}.
        Available options are ${ge3.join(", ")}.
        Defaulting to ${ge3[0]}.`), t = 0));
    const n2 = ge3[t % ge3.length];
    return Et3[n2];
  };
  var Cn2 = (e, t, n2) => q3(z2(), "distort-processor", { distort: e, postgain: t }, { processorOptions: { algorithm: n2 } });
  var Xe3 = (e, t = 36) => {
    let { note: n2, freq: o, octave: a2 = 0 } = e;
    return n2 = n2 || t, typeof n2 == "string" && (n2 = Be3(n2)), !o && typeof n2 == "number" && (o = kt3(n2)), o *= Math.pow(2, a2), Number(o);
  };
  var ue3 = (e, t) => {
    const n2 = t;
    e.onended = function() {
      n2 && n2(), this.onended = null;
    };
  };
  var Y3 = (e) => {
    if (e != null) {
      if (!(e instanceof AudioNode))
        throw new Error("releaseAudioNode can only release an AudioNode");
      if (e.disconnect(), e instanceof AudioScheduledSourceNode) {
        e.onended && e.onended.name !== "cleanup" && j3(
          "[superdough] Deprecation warning: it seems your code path is setting 'node.onended = callback' instead of using the onceEnded helper"
        );
        try {
          e.stop();
        } catch {
          e.start(e.context.currentTime + 5), e.stop();
        }
      }
      e instanceof AudioWorkletNode && e.parameters.get("end")?.setValueAtTime(0, 0);
    }
  };
  var kn2 = (e, t) => {
    ue3(e, () => t.forEach((n2) => Y3(n2)));
  };
  var mt3 = {};
  mt3.generateReverb = function(e, t) {
    for (var n2 = e.audioContext || new AudioContext(), o = n2.sampleRate, a2 = e.numChannels || 2, c3 = e.decayTime * 1.5, s2 = Math.round(e.decayTime * o), d2 = Math.round(c3 * o), l2 = Math.round((e.fadeInTime || 0) * o), i = Math.pow(1 / 1e3, 1 / s2), p2 = n2.createBuffer(a2, d2, o), r = 0; r < a2; r++) {
      for (var h = p2.getChannelData(r), u3 = 0; u3 < d2; u3++)
        h[u3] = Jn2() * Math.pow(i, u3);
      for (var u3 = 0; u3 < l2; u3++)
        h[u3] *= u3 / l2;
    }
    Pn2(p2, e.lpFreqStart || 0, e.lpFreqEnd || 0, e.decayTime, t);
  };
  mt3.generateGraph = function(e, t, n2, o, a2) {
    var c3 = document.createElement("canvas");
    c3.width = t, c3.height = n2;
    var s2 = c3.getContext("2d");
    s2.fillStyle = "#000", s2.fillRect(0, 0, c3.width, c3.height), s2.fillStyle = "#fff";
    for (var d2 = t / e.length, l2 = n2 / (a2 - o), i = 0; i < e.length; i++)
      s2.fillRect(i * d2, n2 - (e[i] - o) * l2, 1, 1);
    return c3;
  };
  var Pn2 = function(e, t, n2, o, a2) {
    if (t == 0) {
      a2(e);
      return;
    }
    var c3 = In2(e), s2 = new OfflineAudioContext(e.numberOfChannels, c3[0].length, e.sampleRate), d2 = s2.createBufferSource();
    d2.buffer = e;
    var l2 = s2.createBiquadFilter();
    t = Math.min(t, e.sampleRate / 2), n2 = Math.min(n2, e.sampleRate / 2), l2.type = "lowpass", l2.Q.value = 1e-4, l2.frequency.setValueAtTime(t, 0), l2.frequency.linearRampToValueAtTime(n2, o), d2.connect(l2), l2.connect(s2.destination), d2.start(), s2.oncomplete = function(i) {
      a2(i.renderedBuffer), Y3(l2), Y3(d2);
    }, s2.startRendering(), window.filterNode = l2;
  };
  var In2 = function(e) {
    for (var t = [], n2 = 0; n2 < e.numberOfChannels; n2++)
      t[n2] = e.getChannelData(n2);
    return t;
  };
  var Jn2 = function() {
    return Math.random() * 2 - 1;
  };
  typeof AudioContext < "u" && (BaseAudioContext.prototype.adjustLength = function(e, t, n2 = 1, o = 0) {
    const a2 = Math.floor(se2(o, 0, 1) * t.length), c3 = t.sampleRate * e, s2 = this.createBuffer(t.numberOfChannels, t.length, t.sampleRate);
    for (let d2 = 0; d2 < t.numberOfChannels; d2++) {
      let l2 = t.getChannelData(d2), i = s2.getChannelData(d2);
      for (let p2 = 0; p2 < c3; p2++) {
        let r = (a2 + p2 * Math.abs(n2)) % l2.length;
        n2 < 1 && (r = r * -1), i[p2] = l2.at(r) || 0;
      }
    }
    return s2;
  }, BaseAudioContext.prototype.createReverb = function(e, t, n2, o, a2, c3, s2) {
    const d2 = this.createConvolver();
    return d2.generate = (l2 = 2, i = 0.1, p2 = 15e3, r = 1e3, h, u3, m3) => {
      d2.duration = l2, d2.fade = i, d2.lp = p2, d2.dim = r, d2.ir = h, d2.irspeed = u3, d2.irbegin = m3, h ? d2.buffer = this.adjustLength(l2, h, u3, m3) : mt3.generateReverb(
        {
          audioContext: this,
          numChannels: 2,
          decayTime: l2,
          fadeInTime: i,
          lpFreqStart: p2,
          lpFreqEnd: r
        },
        (G4) => {
          d2.buffer = G4;
        }
      );
    }, d2.generate(e, t, n2, o, a2, c3, s2), d2;
  });
  var Yt3 = {
    a: { freqs: [660, 1120, 2750, 3e3, 3350], gains: [1, 0.5012, 0.0708, 0.0631, 0.0126], qs: [80, 90, 120, 130, 140] },
    e: { freqs: [440, 1800, 2700, 3e3, 3300], gains: [1, 0.1995, 0.1259, 0.1, 0.1], qs: [70, 80, 100, 120, 120] },
    i: { freqs: [270, 1850, 2900, 3350, 3590], gains: [1, 0.0631, 0.0631, 0.0158, 0.0158], qs: [40, 90, 100, 120, 120] },
    o: { freqs: [430, 820, 2700, 3e3, 3300], gains: [1, 0.3162, 0.0501, 0.0794, 0.01995], qs: [40, 80, 100, 120, 120] },
    u: { freqs: [370, 630, 2750, 3e3, 3400], gains: [1, 0.1, 0.0708, 0.0316, 0.01995], qs: [40, 60, 100, 120, 120] },
    ae: { freqs: [650, 1515, 2400, 3e3, 3350], gains: [1, 0.5, 0.1008, 0.0631, 0.0126], qs: [80, 90, 120, 130, 140] },
    aa: { freqs: [560, 900, 2570, 3e3, 3300], gains: [1, 0.5, 0.0708, 0.0631, 0.0126], qs: [80, 90, 120, 130, 140] },
    oe: { freqs: [500, 1430, 2300, 3e3, 3300], gains: [1, 0.2, 0.0708, 0.0316, 0.01995], qs: [40, 60, 100, 120, 120] },
    ue: { freqs: [250, 1750, 2150, 3200, 3300], gains: [1, 0.1, 0.0708, 0.0316, 0.01995], qs: [40, 60, 100, 120, 120] },
    y: { freqs: [400, 1460, 2400, 3e3, 3300], gains: [1, 0.2, 0.0708, 0.0316, 0.02995], qs: [40, 60, 100, 120, 120] },
    uh: { freqs: [600, 1250, 2100, 3100, 3500], gains: [1, 0.3, 0.0608, 0.0316, 0.01995], qs: [40, 70, 100, 120, 130] },
    un: { freqs: [500, 1240, 2280, 3e3, 3500], gains: [1, 0.1, 0.1708, 0.0216, 0.02995], qs: [40, 60, 100, 120, 120] },
    en: { freqs: [600, 1480, 2450, 3200, 3300], gains: [1, 0.15, 0.0708, 0.0316, 0.02995], qs: [40, 60, 100, 120, 120] },
    an: { freqs: [700, 1050, 2500, 3e3, 3300], gains: [1, 0.1, 0.0708, 0.0316, 0.02995], qs: [40, 60, 100, 120, 120] },
    on: { freqs: [500, 1080, 2350, 3e3, 3300], gains: [1, 0.1, 0.0708, 0.0316, 0.02995], qs: [40, 60, 100, 120, 120] },
    get \u00E6() {
      return this.ae;
    },
    get \u00F8() {
      return this.oe;
    },
    get \u0251() {
      return this.aa;
    },
    get \u00E5() {
      return this.aa;
    },
    get \u00F6() {
      return this.oe;
    },
    get \u00FC() {
      return this.ue;
    },
    get \u0131() {
      return this.y;
    }
  };
  if (typeof GainNode < "u") {
    class e extends GainNode {
      constructor(n2, o) {
        if (super(n2), !Yt3[o])
          throw new Error("vowel: unknown vowel " + o);
        const { gains: a2, qs: c3, freqs: s2 } = Yt3[o];
        this.makeupGain = n2.createGain(), this.filters = [], this.gains = [];
        for (let d2 = 0; d2 < 5; d2++) {
          const l2 = n2.createGain();
          l2.gain.value = a2[d2];
          const i = n2.createBiquadFilter();
          i.type = "bandpass", i.Q.value = c3[d2], i.frequency.value = s2[d2], super.connect(i), i.connect(l2), this.filters.push(i), l2.connect(this.makeupGain), this.gains.push(l2);
        }
        return this.makeupGain.gain.value = 8, this;
      }
      connect(n2) {
        this.makeupGain.connect(n2);
      }
      disconnect() {
        Y3(this.makeupGain), this.filters.forEach(Y3), this.gains.forEach(Y3), super.disconnect(), this.makeupGain = null, this.filters = null, this.gains = null;
      }
    }
    BaseAudioContext.prototype.createVowelFilter = function(t) {
      return new e(this, t);
    };
  }
  var Un2 = "data:text/javascript;base64,dmFyIF89ZnVuY3Rpb24oUil7InVzZSBzdHJpY3QiO3ZhciBXZT1PYmplY3QuZGVmaW5lUHJvcGVydHk7dmFyIFllPShSLFcsWCk9PlcgaW4gUj9XZShSLFcse2VudW1lcmFibGU6ITAsY29uZmlndXJhYmxlOiEwLHdyaXRhYmxlOiEwLHZhbHVlOlh9KTpSW1ddPVg7dmFyIER0PShSLFcsWCk9PlllKFIsdHlwZW9mIFchPSJzeW1ib2wiP1crIiI6VyxYKTtjbGFzcyBYIGV4dGVuZHMgQXVkaW9Xb3JrbGV0UHJvY2Vzc29ye2NvbnN0cnVjdG9yKHQpe3N1cGVyKHQpLHRoaXMuc3RhcnRlZD0hMSx0aGlzLm5iSW5wdXRzPXQubnVtYmVyT2ZJbnB1dHMsdGhpcy5uYk91dHB1dHM9dC5udW1iZXJPZk91dHB1dHMsdGhpcy5ibG9ja1NpemU9dC5wcm9jZXNzb3JPcHRpb25zLmJsb2NrU2l6ZSx0aGlzLmhvcFNpemU9MTI4LHRoaXMubmJPdmVybGFwcz10aGlzLmJsb2NrU2l6ZS90aGlzLmhvcFNpemUsdGhpcy5pbnB1dEJ1ZmZlcnM9bmV3IEFycmF5KHRoaXMubmJJbnB1dHMpLHRoaXMuaW5wdXRCdWZmZXJzSGVhZD1uZXcgQXJyYXkodGhpcy5uYklucHV0cyksdGhpcy5pbnB1dEJ1ZmZlcnNUb1NlbmQ9bmV3IEFycmF5KHRoaXMubmJJbnB1dHMpO2ZvcihsZXQgcz0wO3M8dGhpcy5uYklucHV0cztzKyspdGhpcy5hbGxvY2F0ZUlucHV0Q2hhbm5lbHMocywxKTt0aGlzLm91dHB1dEJ1ZmZlcnM9bmV3IEFycmF5KHRoaXMubmJPdXRwdXRzKSx0aGlzLm91dHB1dEJ1ZmZlcnNUb1JldHJpZXZlPW5ldyBBcnJheSh0aGlzLm5iT3V0cHV0cyk7Zm9yKGxldCBzPTA7czx0aGlzLm5iT3V0cHV0cztzKyspdGhpcy5hbGxvY2F0ZU91dHB1dENoYW5uZWxzKHMsMSl9cmVhbGxvY2F0ZUNoYW5uZWxzSWZOZWVkZWQodCxzKXtmb3IobGV0IGU9MDtlPHRoaXMubmJJbnB1dHM7ZSsrKXtsZXQgaT10W2VdLmxlbmd0aDtpIT10aGlzLmlucHV0QnVmZmVyc1tlXS5sZW5ndGgmJnRoaXMuYWxsb2NhdGVJbnB1dENoYW5uZWxzKGUsaSl9Zm9yKGxldCBlPTA7ZTx0aGlzLm5iT3V0cHV0cztlKyspe2xldCBpPXNbZV0ubGVuZ3RoO2khPXRoaXMub3V0cHV0QnVmZmVyc1tlXS5sZW5ndGgmJnRoaXMuYWxsb2NhdGVPdXRwdXRDaGFubmVscyhlLGkpfX1hbGxvY2F0ZUlucHV0Q2hhbm5lbHModCxzKXt0aGlzLmlucHV0QnVmZmVyc1t0XT1uZXcgQXJyYXkocyk7Zm9yKGxldCBlPTA7ZTxzO2UrKyl0aGlzLmlucHV0QnVmZmVyc1t0XVtlXT1uZXcgRmxvYXQzMkFycmF5KHRoaXMuYmxvY2tTaXplKzEyOCksdGhpcy5pbnB1dEJ1ZmZlcnNbdF1bZV0uZmlsbCgwKTt0aGlzLmlucHV0QnVmZmVyc0hlYWRbdF09bmV3IEFycmF5KHMpLHRoaXMuaW5wdXRCdWZmZXJzVG9TZW5kW3RdPW5ldyBBcnJheShzKTtmb3IobGV0IGU9MDtlPHM7ZSsrKXRoaXMuaW5wdXRCdWZmZXJzSGVhZFt0XVtlXT10aGlzLmlucHV0QnVmZmVyc1t0XVtlXS5zdWJhcnJheSgwLHRoaXMuYmxvY2tTaXplKSx0aGlzLmlucHV0QnVmZmVyc1RvU2VuZFt0XVtlXT1uZXcgRmxvYXQzMkFycmF5KHRoaXMuYmxvY2tTaXplKX1hbGxvY2F0ZU91dHB1dENoYW5uZWxzKHQscyl7dGhpcy5vdXRwdXRCdWZmZXJzW3RdPW5ldyBBcnJheShzKTtmb3IobGV0IGU9MDtlPHM7ZSsrKXRoaXMub3V0cHV0QnVmZmVyc1t0XVtlXT1uZXcgRmxvYXQzMkFycmF5KHRoaXMuYmxvY2tTaXplKSx0aGlzLm91dHB1dEJ1ZmZlcnNbdF1bZV0uZmlsbCgwKTt0aGlzLm91dHB1dEJ1ZmZlcnNUb1JldHJpZXZlW3RdPW5ldyBBcnJheShzKTtmb3IobGV0IGU9MDtlPHM7ZSsrKXRoaXMub3V0cHV0QnVmZmVyc1RvUmV0cmlldmVbdF1bZV09bmV3IEZsb2F0MzJBcnJheSh0aGlzLmJsb2NrU2l6ZSksdGhpcy5vdXRwdXRCdWZmZXJzVG9SZXRyaWV2ZVt0XVtlXS5maWxsKDApfXJlYWRJbnB1dHModCl7aWYodFswXS5sZW5ndGgmJnRbMF1bMF0ubGVuZ3RoPT0wKXtmb3IobGV0IHM9MDtzPHRoaXMubmJJbnB1dHM7cysrKWZvcihsZXQgZT0wO2U8dGhpcy5pbnB1dEJ1ZmZlcnNbc10ubGVuZ3RoO2UrKyl0aGlzLmlucHV0QnVmZmVyc1tzXVtlXS5maWxsKDAsdGhpcy5ibG9ja1NpemUpO3JldHVybn1mb3IobGV0IHM9MDtzPHRoaXMubmJJbnB1dHM7cysrKWZvcihsZXQgZT0wO2U8dGhpcy5pbnB1dEJ1ZmZlcnNbc10ubGVuZ3RoO2UrKyl7bGV0IGk9dFtzXVtlXTt0aGlzLmlucHV0QnVmZmVyc1tzXVtlXS5zZXQoaSx0aGlzLmJsb2NrU2l6ZSl9fXdyaXRlT3V0cHV0cyh0KXtmb3IobGV0IHM9MDtzPHRoaXMubmJJbnB1dHM7cysrKWZvcihsZXQgZT0wO2U8dGhpcy5pbnB1dEJ1ZmZlcnNbc10ubGVuZ3RoO2UrKyl7bGV0IGk9dGhpcy5vdXRwdXRCdWZmZXJzW3NdW2VdLnN1YmFycmF5KDAsMTI4KTt0W3NdW2VdLnNldChpKX19c2hpZnRJbnB1dEJ1ZmZlcnMoKXtmb3IobGV0IHQ9MDt0PHRoaXMubmJJbnB1dHM7dCsrKWZvcihsZXQgcz0wO3M8dGhpcy5pbnB1dEJ1ZmZlcnNbdF0ubGVuZ3RoO3MrKyl0aGlzLmlucHV0QnVmZmVyc1t0XVtzXS5jb3B5V2l0aGluKDAsMTI4KX1zaGlmdE91dHB1dEJ1ZmZlcnMoKXtmb3IobGV0IHQ9MDt0PHRoaXMubmJPdXRwdXRzO3QrKylmb3IobGV0IHM9MDtzPHRoaXMub3V0cHV0QnVmZmVyc1t0XS5sZW5ndGg7cysrKXRoaXMub3V0cHV0QnVmZmVyc1t0XVtzXS5jb3B5V2l0aGluKDAsMTI4KSx0aGlzLm91dHB1dEJ1ZmZlcnNbdF1bc10uc3ViYXJyYXkodGhpcy5ibG9ja1NpemUtMTI4KS5maWxsKDApfXByZXBhcmVJbnB1dEJ1ZmZlcnNUb1NlbmQoKXtmb3IobGV0IHQ9MDt0PHRoaXMubmJJbnB1dHM7dCsrKWZvcihsZXQgcz0wO3M8dGhpcy5pbnB1dEJ1ZmZlcnNbdF0ubGVuZ3RoO3MrKyl0aGlzLmlucHV0QnVmZmVyc1RvU2VuZFt0XVtzXS5zZXQodGhpcy5pbnB1dEJ1ZmZlcnNIZWFkW3RdW3NdKX1oYW5kbGVPdXRwdXRCdWZmZXJzVG9SZXRyaWV2ZSgpe2ZvcihsZXQgdD0wO3Q8dGhpcy5uYk91dHB1dHM7dCsrKWZvcihsZXQgcz0wO3M8dGhpcy5vdXRwdXRCdWZmZXJzW3RdLmxlbmd0aDtzKyspZm9yKGxldCBlPTA7ZTx0aGlzLmJsb2NrU2l6ZTtlKyspdGhpcy5vdXRwdXRCdWZmZXJzW3RdW3NdW2VdKz10aGlzLm91dHB1dEJ1ZmZlcnNUb1JldHJpZXZlW3RdW3NdW2VdL3RoaXMubmJPdmVybGFwc31wcm9jZXNzKHQscyxlKXtjb25zdCBuPXRbMF1bMF0hPT12b2lkIDA7cmV0dXJuIHRoaXMuc3RhcnRlZCYmIW4/ITE6KHRoaXMuc3RhcnRlZD1uLHRoaXMucmVhbGxvY2F0ZUNoYW5uZWxzSWZOZWVkZWQodCxzKSx0aGlzLnJlYWRJbnB1dHModCksdGhpcy5zaGlmdElucHV0QnVmZmVycygpLHRoaXMucHJlcGFyZUlucHV0QnVmZmVyc1RvU2VuZCgpLHRoaXMucHJvY2Vzc09MQSh0aGlzLmlucHV0QnVmZmVyc1RvU2VuZCx0aGlzLm91dHB1dEJ1ZmZlcnNUb1JldHJpZXZlLGUpLHRoaXMuaGFuZGxlT3V0cHV0QnVmZmVyc1RvUmV0cmlldmUoKSx0aGlzLndyaXRlT3V0cHV0cyhzKSx0aGlzLnNoaWZ0T3V0cHV0QnVmZmVycygpLCEwKX1wcm9jZXNzT0xBKHQscyxlKXtjb25zb2xlLmFzc2VydCghMSwiTm90IG92ZXJyaWRlbiIpfX1jbGFzcyBRdHtjb25zdHJ1Y3Rvcih0KXtpZih0aGlzLnNpemU9dHwwLHRoaXMuc2l6ZTw9MXx8dGhpcy5zaXplJnRoaXMuc2l6ZS0xKXRocm93IG5ldyBFcnJvcigiRkZUIHNpemUgbXVzdCBiZSBhIHBvd2VyIG9mIHR3byBhbmQgYmlnZ2VyIHRoYW4gMSIpO3RoaXMuX2NzaXplPXQ8PDE7Zm9yKHZhciBzPW5ldyBBcnJheSh0aGlzLnNpemUqMiksZT0wO2U8cy5sZW5ndGg7ZSs9Mil7Y29uc3QgaD1NYXRoLlBJKmUvdGhpcy5zaXplO3NbZV09TWF0aC5jb3MoaCksc1tlKzFdPS1NYXRoLnNpbihoKX10aGlzLnRhYmxlPXM7Zm9yKHZhciBpPTAsbj0xO3RoaXMuc2l6ZT5uO248PD0xKWkrKzt0aGlzLl93aWR0aD1pJTI9PT0wP2ktMTppLHRoaXMuX2JpdHJldj1uZXcgQXJyYXkoMTw8dGhpcy5fd2lkdGgpO2Zvcih2YXIgYT0wO2E8dGhpcy5fYml0cmV2Lmxlbmd0aDthKyspe3RoaXMuX2JpdHJldlthXT0wO2Zvcih2YXIgbz0wO288dGhpcy5fd2lkdGg7bys9Mil7dmFyIGM9dGhpcy5fd2lkdGgtby0yO3RoaXMuX2JpdHJldlthXXw9KGE+Pj5vJjMpPDxjfX10aGlzLl9vdXQ9bnVsbCx0aGlzLl9kYXRhPW51bGwsdGhpcy5faW52PTB9ZnJvbUNvbXBsZXhBcnJheSh0LHMpe2Zvcih2YXIgZT1zfHxuZXcgQXJyYXkodC5sZW5ndGg+Pj4xKSxpPTA7aTx0Lmxlbmd0aDtpKz0yKWVbaT4+PjFdPXRbaV07cmV0dXJuIGV9Y3JlYXRlQ29tcGxleEFycmF5KCl7Y29uc3QgdD1uZXcgQXJyYXkodGhpcy5fY3NpemUpO2Zvcih2YXIgcz0wO3M8dC5sZW5ndGg7cysrKXRbc109MDtyZXR1cm4gdH10b0NvbXBsZXhBcnJheSh0LHMpe2Zvcih2YXIgZT1zfHx0aGlzLmNyZWF0ZUNvbXBsZXhBcnJheSgpLGk9MDtpPGUubGVuZ3RoO2krPTIpZVtpXT10W2k+Pj4xXSxlW2krMV09MDtyZXR1cm4gZX1jb21wbGV0ZVNwZWN0cnVtKHQpe2Zvcih2YXIgcz10aGlzLl9jc2l6ZSxlPXM+Pj4xLGk9MjtpPGU7aSs9Mil0W3MtaV09dFtpXSx0W3MtaSsxXT0tdFtpKzFdfXRyYW5zZm9ybSh0LHMpe2lmKHQ9PT1zKXRocm93IG5ldyBFcnJvcigiSW5wdXQgYW5kIG91dHB1dCBidWZmZXJzIG11c3QgYmUgZGlmZmVyZW50Iik7dGhpcy5fb3V0PXQsdGhpcy5fZGF0YT1zLHRoaXMuX2ludj0wLHRoaXMuX3RyYW5zZm9ybTQoKSx0aGlzLl9vdXQ9bnVsbCx0aGlzLl9kYXRhPW51bGx9cmVhbFRyYW5zZm9ybSh0LHMpe2lmKHQ9PT1zKXRocm93IG5ldyBFcnJvcigiSW5wdXQgYW5kIG91dHB1dCBidWZmZXJzIG11c3QgYmUgZGlmZmVyZW50Iik7dGhpcy5fb3V0PXQsdGhpcy5fZGF0YT1zLHRoaXMuX2ludj0wLHRoaXMuX3JlYWxUcmFuc2Zvcm00KCksdGhpcy5fb3V0PW51bGwsdGhpcy5fZGF0YT1udWxsfWludmVyc2VUcmFuc2Zvcm0odCxzKXtpZih0PT09cyl0aHJvdyBuZXcgRXJyb3IoIklucHV0IGFuZCBvdXRwdXQgYnVmZmVycyBtdXN0IGJlIGRpZmZlcmVudCIpO3RoaXMuX291dD10LHRoaXMuX2RhdGE9cyx0aGlzLl9pbnY9MSx0aGlzLl90cmFuc2Zvcm00KCk7Zm9yKHZhciBlPTA7ZTx0Lmxlbmd0aDtlKyspdFtlXS89dGhpcy5zaXplO3RoaXMuX291dD1udWxsLHRoaXMuX2RhdGE9bnVsbH1fdHJhbnNmb3JtNCgpe3ZhciB0PXRoaXMuX291dCxzPXRoaXMuX2NzaXplLGU9dGhpcy5fd2lkdGgsaT0xPDxlLG49cy9pPDwxLGEsbyxjPXRoaXMuX2JpdHJldjtpZihuPT09NClmb3IoYT0wLG89MDthPHM7YSs9bixvKyspe2NvbnN0IG09Y1tvXTt0aGlzLl9zaW5nbGVUcmFuc2Zvcm0yKGEsbSxpKX1lbHNlIGZvcihhPTAsbz0wO2E8czthKz1uLG8rKyl7Y29uc3QgbT1jW29dO3RoaXMuX3NpbmdsZVRyYW5zZm9ybTQoYSxtLGkpfXZhciBoPXRoaXMuX2ludj8tMToxLGY9dGhpcy50YWJsZTtmb3IoaT4+PTI7aT49MjtpPj49Mil7bj1zL2k8PDE7dmFyIHU9bj4+PjI7Zm9yKGE9MDthPHM7YSs9bilmb3IodmFyIGQ9YSt1LGw9YSxwPTA7bDxkO2wrPTIscCs9aSl7Y29uc3QgbT1sLEk9bSt1LHc9SSt1LHY9dyt1LE09dFttXSxQPXRbbSsxXSxnPXRbSV0sVD10W0krMV0sQT10W3ddLFY9dFt3KzFdLE89dFt2XSxOPXRbdisxXSxDPU0sRj1QLHE9ZltwXSxCPWgqZltwKzFdLEw9ZypxLVQqQixFPWcqQitUKnEsSD1mWzIqcF0saXQ9aCpmWzIqcCsxXSwkPUEqSC1WKml0LFU9QSppdCtWKkgsSz1mWzMqcF0sWj1oKmZbMypwKzFdLGs9TypLLU4qWixmdD1PKlorTipLLGR0PUMrJCxydD1GK1UsbnQ9Qy0kLHB0PUYtVSxtdD1MK2ssYXQ9RStmdCxvdD1oKihMLWspLGd0PWgqKEUtZnQpLHZ0PWR0K210LEF0PXJ0K2F0LE90PWR0LW10LE50PXJ0LWF0LEN0PW50K2d0LEZ0PXB0LW90LEV0PW50LWd0LGt0PXB0K290O3RbbV09dnQsdFttKzFdPUF0LHRbSV09Q3QsdFtJKzFdPUZ0LHRbd109T3QsdFt3KzFdPU50LHRbdl09RXQsdFt2KzFdPWt0fX19X3NpbmdsZVRyYW5zZm9ybTIodCxzLGUpe2NvbnN0IGk9dGhpcy5fb3V0LG49dGhpcy5fZGF0YSxhPW5bc10sbz1uW3MrMV0sYz1uW3MrZV0saD1uW3MrZSsxXSxmPWErYyx1PW8raCxkPWEtYyxsPW8taDtpW3RdPWYsaVt0KzFdPXUsaVt0KzJdPWQsaVt0KzNdPWx9X3NpbmdsZVRyYW5zZm9ybTQodCxzLGUpe2NvbnN0IGk9dGhpcy5fb3V0LG49dGhpcy5fZGF0YSxhPXRoaXMuX2ludj8tMToxLG89ZSoyLGM9ZSozLGg9bltzXSxmPW5bcysxXSx1PW5bcytlXSxkPW5bcytlKzFdLGw9bltzK29dLHA9bltzK28rMV0sbT1uW3MrY10sST1uW3MrYysxXSx3PWgrbCx2PWYrcCxNPWgtbCxQPWYtcCxnPXUrbSxUPWQrSSxBPWEqKHUtbSksVj1hKihkLUkpLE89dytnLE49ditULEM9TStWLEY9UC1BLHE9dy1nLEI9di1ULEw9TS1WLEU9UCtBO2lbdF09TyxpW3QrMV09TixpW3QrMl09QyxpW3QrM109RixpW3QrNF09cSxpW3QrNV09QixpW3QrNl09TCxpW3QrN109RX1fcmVhbFRyYW5zZm9ybTQoKXt2YXIgdD10aGlzLl9vdXQscz10aGlzLl9jc2l6ZSxlPXRoaXMuX3dpZHRoLGk9MTw8ZSxuPXMvaTw8MSxhLG8sYz10aGlzLl9iaXRyZXY7aWYobj09PTQpZm9yKGE9MCxvPTA7YTxzO2ErPW4sbysrKXtjb25zdCBSdD1jW29dO3RoaXMuX3NpbmdsZVJlYWxUcmFuc2Zvcm0yKGEsUnQ+Pj4xLGk+Pj4xKX1lbHNlIGZvcihhPTAsbz0wO2E8czthKz1uLG8rKyl7Y29uc3QgUnQ9Y1tvXTt0aGlzLl9zaW5nbGVSZWFsVHJhbnNmb3JtNChhLFJ0Pj4+MSxpPj4+MSl9dmFyIGg9dGhpcy5faW52Py0xOjEsZj10aGlzLnRhYmxlO2ZvcihpPj49MjtpPj0yO2k+Pj0yKXtuPXMvaTw8MTt2YXIgdT1uPj4+MSxkPXU+Pj4xLGw9ZD4+PjE7Zm9yKGE9MDthPHM7YSs9bilmb3IodmFyIHA9MCxtPTA7cDw9bDtwKz0yLG0rPWkpe3ZhciBJPWErcCx3PUkrZCx2PXcrZCxNPXYrZCxQPXRbSV0sZz10W0krMV0sVD10W3ddLEE9dFt3KzFdLFY9dFt2XSxPPXRbdisxXSxOPXRbTV0sQz10W00rMV0sRj1QLHE9ZyxCPWZbbV0sTD1oKmZbbSsxXSxFPVQqQi1BKkwsSD1UKkwrQSpCLGl0PWZbMiptXSwkPWgqZlsyKm0rMV0sVT1WKml0LU8qJCxLPVYqJCtPKml0LFo9ZlszKm1dLGs9aCpmWzMqbSsxXSxmdD1OKlotQyprLGR0PU4qaytDKloscnQ9RitVLG50PXErSyxwdD1GLVUsbXQ9cS1LLGF0PUUrZnQsb3Q9SCtkdCxndD1oKihFLWZ0KSx2dD1oKihILWR0KSxBdD1ydCthdCxPdD1udCtvdCxOdD1wdCt2dCxDdD1tdC1ndDtpZih0W0ldPUF0LHRbSSsxXT1PdCx0W3ddPU50LHRbdysxXT1DdCxwPT09MCl7dmFyIEZ0PXJ0LWF0LEV0PW50LW90O3Rbdl09RnQsdFt2KzFdPUV0O2NvbnRpbnVlfWlmKHAhPT1sKXt2YXIga3Q9cHQsT2U9LW10LE5lPXJ0LENlPS1udCxGZT0taCp2dCxFZT0taCpndCxrZT0taCpvdCxSZT0taCphdCxEZT1rdCtGZSx6ZT1PZStFZSxxZT1OZStSZSxMZT1DZS1rZSxadD1hK2QtcCxYdD1hK3UtcDt0W1p0XT1EZSx0W1p0KzFdPXplLHRbWHRdPXFlLHRbWHQrMV09TGV9fX19X3NpbmdsZVJlYWxUcmFuc2Zvcm0yKHQscyxlKXtjb25zdCBpPXRoaXMuX291dCxuPXRoaXMuX2RhdGEsYT1uW3NdLG89bltzK2VdLGM9YStvLGg9YS1vO2lbdF09YyxpW3QrMV09MCxpW3QrMl09aCxpW3QrM109MH1fc2luZ2xlUmVhbFRyYW5zZm9ybTQodCxzLGUpe2NvbnN0IGk9dGhpcy5fb3V0LG49dGhpcy5fZGF0YSxhPXRoaXMuX2ludj8tMToxLG89ZSoyLGM9ZSozLGg9bltzXSxmPW5bcytlXSx1PW5bcytvXSxkPW5bcytjXSxsPWgrdSxwPWgtdSxtPWYrZCxJPWEqKGYtZCksdz1sK20sdj1wLE09LUksUD1sLW0sZz1wLFQ9STtpW3RdPXcsaVt0KzFdPTAsaVt0KzJdPXYsaVt0KzNdPU0saVt0KzRdPVAsaVt0KzVdPTAsaVt0KzZdPWcsaVt0KzddPVR9fWxldCB0cz1yPT5jb25zb2xlLmxvZyhyKTtjb25zdCBzcz0oLi4ucik9PnRzKC4uLnIpLGVzPShyLHQscyk9Pk1hdGgubWluKE1hdGgubWF4KHIsdCkscyksenQ9cj0+ci8oMStyKSxpcz0ocix0KT0+KHIldCt0KSV0LHJzPShyLHQpPT4oMSt0KSpyLygxK3QqTWF0aC5hYnMocikpLEo9KHIsdCk9Pk1hdGgudGFuaChyKigxK3QpKSxucz0ocix0KT0+ZXMoKDErdCkqciwtMSwxKSxxdD0ocix0KT0+e2xldCBzPSgxKy41KnQpKnI7Y29uc3QgZT1pcyhzKzEsNCk7cmV0dXJuIDEtTWF0aC5hYnMoZS0yKX0sYXM9KHIsdCk9Pk1hdGguc2luKE1hdGguUEkvMipxdChyLHQpKSxvcz0ocix0KT0+e2NvbnN0IHM9enQoTWF0aC5sb2cxcCh0KSksZT0oci1zLzMqcipyKnIpLygxLXMvMyk7cmV0dXJuIEooZSx0KX0sTHQ9KHIsdCxzPSExKT0+e2NvbnN0IGU9MSsyKnQsbj0uMDcqenQoTWF0aC5sb2cxcCh0KSksYT1KKHIrbiwyKnQpLG89SihzP246LXIrbiwyKnQpLGM9YS1vLGg9MS9NYXRoLmNvc2goZSpuKSxmPWgqaCx1PU1hdGgubWF4KDFlLTgsKHM/MToyKSplKmYpO3JldHVybiBKKGMvdSx0KX0sV3Q9e3NjdXJ2ZTpycyxzb2Z0OkosaGFyZDpucyxjdWJpYzpvcyxkaW9kZTpMdCxhc3ltOihyLHQpPT5MdChyLHQsITApLGZvbGQ6cXQsc2luZWZvbGQ6YXMsY2hlYnlzaGV2OihyLHQpPT57Y29uc3Qgcz0xMCpNYXRoLmxvZzFwKHQpO2xldCBlPTEsaT1yLG4sYT0wO2ZvcihsZXQgbz0xO288NjQ7bysrKXtpZihvPDIpe2ErPW89PTA/ZTppO2NvbnRpbnVlfW49MipyKmUtaSxpPWUsZT1uLG8lMj09PTAmJihhKz1NYXRoLm1pbigxLjMqcy9vLDIpKm4pfXJldHVybiBKKGEscy8yMCl9fSxodD1PYmplY3QuZnJlZXplKE9iamVjdC5rZXlzKFd0KSksaHM9cj0+e2xldCB0PXI7dHlwZW9mIHI9PSJzdHJpbmciJiYodD1odC5pbmRleE9mKHIpLHQ9PT0tMSYmKHNzKGBbc3VwZXJkb3VnaF0gQ291bGQgbm90IGZpbmQgd2F2ZXNoYXBpbmcgYWxnb3JpdGhtICR7cn0uCiAgICAgICAgQXZhaWxhYmxlIG9wdGlvbnMgYXJlICR7aHQuam9pbigiLCAiKX0uCiAgICAgICAgRGVmYXVsdGluZyB0byAke2h0WzBdfS5gKSx0PTApKTtjb25zdCBzPWh0W3QlaHQubGVuZ3RoXTtyZXR1cm4gV3Rbc119O2Z1bmN0aW9uIGN0KHIsdCl7aWYodHx8KHQ9ImFzc2VydGlvbiBmYWlsZWQiKSwhcil0aHJvdyBuZXcgRXJyb3IodCl9ZnVuY3Rpb24gY3Mocix0LHMpe3JldHVybiByPD0wP3Q6cj49MT9zOnQrcioocy10KX1mdW5jdGlvbiB1cyhyLHQscyl7cmV0dXJuIHI8PXQ/MDpyPj1zPzE6cz09PXQ/MDooci10KS8ocy10KX1mdW5jdGlvbiBscyhyLHQpe3JldHVybiByPHQ/KHIvPXQscityLXIqci0xKTpyPjEtdD8ocj0oci0xKS90LHIqcityK3IrMSk6MH1mdW5jdGlvbiBmcyhyKXtyZXR1cm4gTWF0aC5mbG9vcihyKT09PXJ9ZnVuY3Rpb24gZHMocil7cmV0dXJuIGZzKHIpJiZyPjB9ZnVuY3Rpb24gcHMocix0KXt0PU1hdGgubWluKE1hdGgubWF4KHQsMCksMSksdC09LjAxO3ZhciBzPTIqdC8oMS10KSxlPSgxK3MpKnIvKDErcypNYXRoLmFicyhyKSk7cmV0dXJuIGV9ZnVuY3Rpb24gSXQocix0LHMpe3JldHVybiByPj0xP3M6dCtyKihzLXQpfWZ1bmN0aW9uIFl0KCl7dGhpcy5zdGF0ZT0ib2ZmIix0aGlzLnN0YXJ0VGltZT0wLHRoaXMuc3RhcnRWYWw9MH1ZdC5wcm90b3R5cGUuZXZhbD1mdW5jdGlvbihyLHQscyxlLGksbil7c3dpdGNoKHRoaXMuc3RhdGUpe2Nhc2Uib2ZmIjpyZXR1cm4gdD4wJiYodGhpcy5zdGF0ZT0iYXR0YWNrIix0aGlzLnN0YXJ0VGltZT1yLHRoaXMuc3RhcnRWYWw9MCksMDtjYXNlImF0dGFjayI6e2xldCBhPXItdGhpcy5zdGFydFRpbWU7cmV0dXJuIGE+cz8odGhpcy5zdGF0ZT0iZGVjYXkiLHRoaXMuc3RhcnRUaW1lPXIsMSk6SXQoYS9zLHRoaXMuc3RhcnRWYWwsMSl9Y2FzZSJkZWNheSI6e2xldCBhPXItdGhpcy5zdGFydFRpbWUsbz1JdChhL2UsMSxpKTtyZXR1cm4gdDw9MD8odGhpcy5zdGF0ZT0icmVsZWFzZSIsdGhpcy5zdGFydFRpbWU9cix0aGlzLnN0YXJ0VmFsPW8sbyk6YT5lPyh0aGlzLnN0YXRlPSJzdXN0YWluIix0aGlzLnN0YXJ0VGltZT1yLGkpOm99Y2FzZSJzdXN0YWluIjpyZXR1cm4gdDw9MCYmKHRoaXMuc3RhdGU9InJlbGVhc2UiLHRoaXMuc3RhcnRUaW1lPXIsdGhpcy5zdGFydFZhbD1pKSxpO2Nhc2UicmVsZWFzZSI6e2xldCBhPXItdGhpcy5zdGFydFRpbWU7aWYoYT5uKXJldHVybiB0aGlzLnN0YXRlPSJvZmYiLDA7bGV0IG89SXQoYS9uLHRoaXMuc3RhcnRWYWwsMCk7cmV0dXJuIHQ+MCYmKHRoaXMuc3RhdGU9ImF0dGFjayIsdGhpcy5zdGFydFRpbWU9cix0aGlzLnN0YXJ0VmFsPW8pLG99fXRocm93ImludmFsaWQgZW52ZWxvcGUgc3RhdGUifTtmdW5jdGlvbiB3dCgpe3RoaXMuczA9MCx0aGlzLnMxPTB9d3QucHJvdG90eXBlLmFwcGx5PWZ1bmN0aW9uKHIsdCxzKXtjdCghaXNOYU4ociksIk5hTiB2YWx1ZSBmZWQgaW4gVHdvUG9sZUZpbHRlciIpLHQ9TWF0aC5taW4odCwxKSxzPU1hdGgubWF4KHMsMCk7dmFyIGU9TWF0aC5wb3coLjUsKDEtdCkvLjEyNSksaT1NYXRoLnBvdyguNSwocysuMTI1KS8uMTI1KSxuPTEtaSplLGE9dGhpcy5zMCxvPXRoaXMuczE7cmV0dXJuIGE9biphLWUqbytlKnIsbz1uKm8rZSphLHI9byx0aGlzLnMwPWEsdGhpcy5zMT1vLHJ9O2xldCBtcz1jbGFzcyBKdHtjb25zdHJ1Y3Rvcih0LHMpe3RoaXMuc2FtcGxlUmF0ZT10LHM/dGhpcy5idWZmZXI9cy5zbGljZSgwKToodGhpcy5idWZmZXI9bmV3IEZsb2F0MzJBcnJheSgxMCp0KSx0aGlzLmJ1ZmZlci5maWxsKDApKSx0aGlzLndyaXRlSWR4PTAsdGhpcy5yZWFkSWR4PTB9cmVzZXQoKXt0aGlzLmJ1ZmZlci5maWxsKDApLHRoaXMud3JpdGVJZHg9MCx0aGlzLnJlYWRJZHg9MH1jbG9uZSgpe2NvbnN0IHQ9bmV3IEp0KHRoaXMuc2FtcGxlUmF0ZSx0aGlzLmJ1ZmZlcik7cmV0dXJuIHQud3JpdGVJZHg9dGhpcy53cml0ZUlkeCx0LnJlYWRJZHg9dGhpcy5yZWFkSWR4LHR9d3JpdGUodCxzKXt0aGlzLndyaXRlSWR4PSh0aGlzLndyaXRlSWR4KzEpJXRoaXMuYnVmZmVyLmxlbmd0aCx0aGlzLmJ1ZmZlclt0aGlzLndyaXRlSWR4XT10O2xldCBlPU1hdGgubWluKE1hdGguZmxvb3IodGhpcy5zYW1wbGVSYXRlKnMpLHRoaXMuYnVmZmVyLmxlbmd0aC0xKTt0aGlzLnJlYWRJZHg9dGhpcy53cml0ZUlkeC1lLHRoaXMucmVhZElkeDwwJiYodGhpcy5yZWFkSWR4Kz10aGlzLmJ1ZmZlci5sZW5ndGgpfXJlYWQoKXtyZXR1cm4gdGhpcy5idWZmZXJbdGhpcy5yZWFkSWR4XX19O2NvbnN0IFN0PTEvNDhlMyxfdD0yNCxncz1fdC80O2NsYXNzIHl7Y29uc3RydWN0b3IodCxzLGUsaSl7dGhpcy5ub2RlSWQ9dCx0aGlzLnN0YXRlPXMsdGhpcy5zYW1wbGVSYXRlPWUsdGhpcy5zYW1wbGVUaW1lPTEvZSx0aGlzLnNlbmQ9aX19Y2xhc3MgYnMgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMuZW52PW5ldyBZdH11cGRhdGUodCxzLGUsaSxuLGEpe3JldHVybiB0aGlzLmVudi5ldmFsKHQscyxlLGksbixhKX19Y2xhc3MgdnMgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MH11cGRhdGUodCl7bGV0IHM9X3QqdC82MCxlPS41O3JldHVybiB0aGlzLnBoYXNlKz10aGlzLnNhbXBsZVRpbWUqcyx0aGlzLnBoYXNlJTE8ZT8xOi0xfX1jbGFzcyBJcyBleHRlbmRzIHl7Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5pblNnbj0hMCx0aGlzLm91dFNnbj0hMCx0aGlzLmNsb2NrQ250PTB9dXBkYXRlKHQscyl7bGV0IGU9dD4wO3JldHVybiB0aGlzLmluU2duIT1lJiYodGhpcy5jbG9ja0NudCsrLHRoaXMuY2xvY2tDbnQ+PXMmJih0aGlzLmNsb2NrQ250PTAsdGhpcy5vdXRTZ249IXRoaXMub3V0U2duKSksdGhpcy5pblNnbj1lLHRoaXMub3V0U2duPzE6LTF9fWNsYXNzIHdzIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLmluU2duPSExfXVwZGF0ZSh0LHMpe2xldCBlPXM+MDtyZXR1cm4gZSYmdGhpcy5pblNnbiE9ZSYmdGhpcy5zZW5kKHt0eXBlOiJDTE9DS19QVUxTRSIsbm9kZUlkOnRoaXMubm9kZUlkLHRpbWU6dH0pLHRoaXMuaW5TZ249ZSwwfX1jb25zdCBNdD1uZXcgTWFwO2NsYXNzIFNzIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKTtjb25zdCBuPXMuaW5wdXRzWzJdO24mJk10LmhhcyhuKT90aGlzLmRlbGF5PU10LmdldChuKS5jbG9uZSgpOnRoaXMuZGVsYXk9bmV3IG1zKGUpLG4mJk10LnNldChuLHRoaXMuZGVsYXkpfXVwZGF0ZSh0LHMpe3JldHVybiB0aGlzLmRlbGF5LndyaXRlKHQscyksdGhpcy5kZWxheS5yZWFkKCl9fWNsYXNzIF9zIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKX11cGRhdGUodCxzKXtyZXR1cm4gcHModCxzKX19Y2xhc3MgTXMgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMudmFsdWU9MCx0aGlzLnRyaWdTZ249ITF9d3JpdGUodCxzKXshdGhpcy50cmlnU2duJiZzPjAmJih0aGlzLnZhbHVlPXQpLHRoaXMudHJpZ1Nnbj1zPjB9cmVhZCgpe3JldHVybiB0aGlzLnZhbHVlfXVwZGF0ZSh0LHMpe3JldHVybiB0aGlzLndyaXRlKHQscyksdGhpcy5yZWFkKCl9fWNsYXNzIHhze2NvbnN0cnVjdG9yKCl7dGhpcy52YWx1ZT0wfXVwZGF0ZSh0KXtyZXR1cm4gdGhpcy52YWx1ZT10LHRoaXMudmFsdWV9fWNvbnN0IHlzPTM0MDtsZXQgR3Q9MDtjbGFzcyBQc3tjb25zdHJ1Y3Rvcigpe3RoaXMuY2g9R3QsdGhpcy5zdGFydF9zZWVkPXlzKih0aGlzLmNoKzEpPj4+MCx0aGlzLnN0YXRlPXRoaXMuc3RhcnRfc2VlZCx0aGlzLnZhbHVlPTAsdGhpcy5hPTE2NjQ1MjUsdGhpcy5jPTEwMTM5MDQyMjMsdGhpcy5tYXNrPTE2Nzc3MjE1LHRoaXMuc2NhbGU9NTk2MDQ2NDQ3NzUzOTA2M2UtMjMsR3QrK311cGRhdGUodCxzKXtpZighdClyZXR1cm4gdGhpcy52YWx1ZTtzJiYodGhpcy5zdGF0ZT10aGlzLnN0YXJ0X3NlZWQpLHRoaXMuc3RhdGU9dGhpcy5zdGF0ZSp0aGlzLmErdGhpcy5jPj4+MDtjb25zdCBlPSh0aGlzLnN0YXRlJnRoaXMubWFzaykqdGhpcy5zY2FsZTtyZXR1cm4gdGhpcy52YWx1ZT1lKjItMSx0aGlzLnZhbHVlfX1jbGFzcyBUc3tjb25zdHJ1Y3Rvcigpe3RoaXMudmFsdWU9TWF0aC5yYW5kb20oKSoyLTF9dXBkYXRlKHQpe3JldHVybiB0Pyh0aGlzLnZhbHVlPU1hdGgucmFuZG9tKCkqMi0xLHRoaXMudmFsdWUpOnRoaXMudmFsdWV9fWNsYXNzIEJze3VwZGF0ZSh0KXtyZXR1cm4gTWF0aC5yYW5kb20oKTx0KlN0P01hdGgucmFuZG9tKCk6MH19Y2xhc3MgVnN7Y29uc3RydWN0b3IoKXt0aGlzLm91dD0wfXVwZGF0ZSgpe2xldCB0PU1hdGgucmFuZG9tKCkqMi0xO3JldHVybiB0aGlzLm91dD0odGhpcy5vdXQrLjAyKnQpLzEuMDIsdGhpcy5vdXR9fWNsYXNzIEFze2NvbnN0cnVjdG9yKCl7dGhpcy5iMD0wLHRoaXMuYjE9MCx0aGlzLmIyPTAsdGhpcy5iMz0wLHRoaXMuYjQ9MCx0aGlzLmI1PTAsdGhpcy5iNj0wfXVwZGF0ZSgpe2NvbnN0IHQ9TWF0aC5yYW5kb20oKSoyLTE7dGhpcy5iMD0uOTk4ODYqdGhpcy5iMCt0Ki4wNTU1MTc5LHRoaXMuYjE9Ljk5MzMyKnRoaXMuYjErdCouMDc1MDc1OSx0aGlzLmIyPS45NjkqdGhpcy5iMit0Ki4xNTM4NTIsdGhpcy5iMz0uODY2NSp0aGlzLmIzK3QqLjMxMDQ4NTYsdGhpcy5iND0uNTUqdGhpcy5iNCt0Ki41MzI5NTIyLHRoaXMuYjU9LS43NjE2KnRoaXMuYjUtdCouMDE2ODk4O2NvbnN0IHM9dGhpcy5iMCt0aGlzLmIxK3RoaXMuYjIrdGhpcy5iMyt0aGlzLmI0K3RoaXMuYjUrdGhpcy5iNit0Ki41MzYyO3JldHVybiB0aGlzLmI2PXQqLjExNTkyNixzKi4xMX19Y2xhc3MgT3MgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MX11cGRhdGUodCl7dGhpcy5waGFzZSs9dGhpcy5zYW1wbGVUaW1lKnQ7bGV0IHM9dGhpcy5waGFzZT49MT8xOjA7cmV0dXJuIHRoaXMucGhhc2U9dGhpcy5waGFzZSUxLHN9fWNsYXNzIE5zIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLnBoYXNlPTB9dXBkYXRlKHQscyl7cmV0dXJuIHRoaXMucGhhc2UrPXRoaXMuc2FtcGxlVGltZSp0LHRoaXMucGhhc2UlMTxzPzE6LTF9fWNsYXNzIENzIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLnBoYXNlPTB9dXBkYXRlKHQpe3JldHVybiB0aGlzLnBoYXNlKz10aGlzLnNhbXBsZVRpbWUqdCx0aGlzLnBoYXNlJTEqMi0xfX1jbGFzcyBGc3tjb25zdHJ1Y3Rvcigpe3RoaXMucGhhc2U9TWF0aC5yYW5kb20oKX11cGRhdGUodCl7Y29uc3Qgcz10L3NhbXBsZVJhdGU7bGV0IGU9bHModGhpcy5waGFzZSxzKSxpPTIqdGhpcy5waGFzZS0xLWU7cmV0dXJuIHRoaXMucGhhc2UrPXMsdGhpcy5waGFzZT4xJiYodGhpcy5waGFzZS09MSksaX19Y2xhc3MgRXMgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MCx0aGlzLnN5bmNTZ249ITF9dXBkYXRlKHQscyxlKXshdGhpcy5zeW5jU2duJiZzPjAmJih0aGlzLnBoYXNlPTApLHRoaXMuc3luY1Nnbj1zPjA7bGV0IGk9KHRoaXMucGhhc2UrZSklMTtyZXR1cm4gdGhpcy5waGFzZSs9dGhpcy5zYW1wbGVUaW1lKnQsTWF0aC5zaW4oaSoyKk1hdGguUEkpfX1jbGFzcyBrc3tkQlRvTGluZWFyKHQpe3JldHVybiBNYXRoLnBvdygxMCx0LzIwKX1saW5lYXJUb0RCKHQpe3JldHVybiAyMCpNYXRoLmxvZzEwKHQpfXVwZGF0ZSh0LHMsZSl7bGV0IGk9dGhpcy5saW5lYXJUb0RCKE1hdGguYWJzKHQpKSxuPTA7cmV0dXJuIGk+cyYmKG49KGktcykqKDEtMS9lKSksdGhpcy5kQlRvTGluZWFyKC1uKX19Y2xhc3MgUnMgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMucGhhc2U9MH11cGRhdGUodCl7dGhpcy5waGFzZSs9dGhpcy5zYW1wbGVUaW1lKnQ7bGV0IHM9dGhpcy5waGFzZSUxO3JldHVybihzPC41PzIqczoxLTIqKHMtLjUpKSoyLTF9fWNsYXNzIERzIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKTtjb25zdCBuPWUvMzA7Y3QoZHMobikpLHRoaXMuYnVmZmVyPW5ldyBGbG9hdDMyQXJyYXkobiksdGhpcy53cml0ZVBvcz0wfXVwZGF0ZSh0LHMsZSxpKXtyZXR1cm4gdGhpcy5idWZmZXJbdGhpcy53cml0ZVBvc109dCx0aGlzLndyaXRlUG9zKyssdGhpcy53cml0ZVBvcyV0aGlzLmJ1ZmZlci5sZW5ndGg9PTAmJih0aGlzLndyaXRlUG9zPTAsdGhpcy5zZW5kKHt0eXBlOiJTRU5EX1NBTVBMRVMiLGlkOnMsc2FtcGxlczp0aGlzLmJ1ZmZlcixjaGFubmVsczplLGNoYW5uZWw6aX0pKSx0fX1jbGFzcyB6c3tjb25zdHJ1Y3Rvcigpe3RoaXMubGFnVW5pdD00NDEwLHRoaXMucz0wfXVwZGF0ZSh0LHMpe3JldHVybiBzPXMqdGhpcy5sYWdVbml0LHM8MSYmKHM9MSksdGhpcy5zKz0xL3MqKHQtdGhpcy5zKSx0aGlzLnN9fWNsYXNzIHFze2NvbnN0cnVjdG9yKCl7dGhpcy5sYXN0PTB9dXBkYXRlKHQscyxlKXtjb25zdCBpPXMqU3Qsbj1lKlN0O2xldCBhPXQtdGhpcy5sYXN0O3JldHVybiBhPmk/YT1pOmE8LW4mJihhPS1uKSx0aGlzLmxhc3QrPWEsdGhpcy5sYXN0fX1jbGFzcyBMcyBleHRlbmRzIHl7Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5zPTB9dXBkYXRlKHQscyl7cmV0dXJuIHM9cyoxZTMsczwxJiYocz0xKSx0aGlzLnMrPTEvcyoodC10aGlzLnMpLHRoaXMuc319Y2xhc3MgV3MgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMuZmlsdGVyPW5ldyB3dH11cGRhdGUodCxzLGUpe3JldHVybiB0aGlzLmZpbHRlci5hcHBseSh0LHMsZSksdGhpcy5maWx0ZXIuczF9fWNsYXNzIFlzIGV4dGVuZHMgeXtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLmZpbHRlcj1uZXcgd3R9dXBkYXRlKHQscyxlKXtyZXR1cm4gdGhpcy5maWx0ZXIuYXBwbHkodCxzLGUpLHRoaXMuZmlsdGVyLnMwfX1jbGFzcyBHcyBleHRlbmRzIHl7Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSl9dXBkYXRlKHQscyl7cmV0dXJuIHM8MCYmKHM9MCkscz1zKzEsdD10KnMsNCooTWF0aC5hYnMoLjI1KnQrLjI1LU1hdGgucm91bmQoLjI1KnQrLjI1KSktLjI1KX19Y2xhc3MganMgZXh0ZW5kcyB5e3VwZGF0ZSh0KXtyZXR1cm4gdH19Y2xhc3MgYnQgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMubm90ZT0wLHRoaXMuZnJlcT0wLHRoaXMudmVsb2NpdHk9MCx0aGlzLmdhdGVTdGF0ZT0ib2ZmIix0aGlzLnR5cGU9Im1pZGlpbiIsdGhpcy5jaGFubmVsPS0xfWlzRnJlZSgpe3JldHVybiB0aGlzLmdhdGVTdGF0ZT09PSJvZmYifW5vdGVPbih0LHMpe3M+MD8odGhpcy5ub3RlPXQsdGhpcy52ZWxvY2l0eT1zLHRoaXMuZnJlcT0yKiooKHQtNjkpLzEyKSo0NDAsdGhpcy5nYXRlU3RhdGU9InByZXRyaWciKTp0aGlzLm5vdGVPZmYoKX1ub3RlT2ZmKCl7dGhpcy5ub3RlPTAsdGhpcy5nYXRlU3RhdGU9Im9mZiJ9Z2V0R2F0ZSgpe3N3aXRjaCh0aGlzLmdhdGVTdGF0ZSl7Y2FzZSJwcmV0cmlnIjpyZXR1cm4gdGhpcy5nYXRlU3RhdGU9Im9uIiwwO2Nhc2Uib24iOnJldHVybiAxO2Nhc2Uib2ZmIjpyZXR1cm4gMDtkZWZhdWx0OmN0KCExKX19Z2V0RnJlcSgpe3N3aXRjaCh0aGlzLmdhdGVTdGF0ZSl7Y2FzZSJwcmV0cmlnIjpyZXR1cm4gdGhpcy5nYXRlU3RhdGU9Im9uIiwwO2Nhc2Uib24iOnJldHVybiB0aGlzLmZyZXE7Y2FzZSJvZmYiOnJldHVybiB0aGlzLmZyZXE7ZGVmYXVsdDpjdCghMSl9fWdldFZlbG9jaXR5KCl7c3dpdGNoKHRoaXMuZ2F0ZVN0YXRlKXtjYXNlInByZXRyaWciOnJldHVybiB0aGlzLmdhdGVTdGF0ZT0ib24iLDA7Y2FzZSJvbiI6cmV0dXJuIHRoaXMudmVsb2NpdHk7Y2FzZSJvZmYiOnJldHVybiB0aGlzLnZlbG9jaXR5O2RlZmF1bHQ6Y3QoITEpfX19Y2xhc3MgSHMgZXh0ZW5kcyBidHtjb25zdHJ1Y3Rvcih0LHMsZSxpKXtzdXBlcih0LHMsZSxpKSx0aGlzLnR5cGU9Im1pZGlnYXRlIn11cGRhdGUodCl7cmV0dXJuIHRoaXMuY2hhbm5lbD10LHRoaXMuZ2V0R2F0ZSgpfX1jbGFzcyBVcyBleHRlbmRzIGJ0e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMudHlwZT0ibWlkaWZyZXEifXVwZGF0ZSh0KXtyZXR1cm4gdGhpcy5jaGFubmVsPXQsdGhpcy5nZXRGcmVxKCl9fWNsYXNzICRzIGV4dGVuZHMgYnR7Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy50eXBlPSJtaWRpdmVsIn11cGRhdGUodCl7cmV0dXJuIHRoaXMuY2hhbm5lbD10LHRoaXMuZ2V0VmVsb2NpdHkoKX19Y2xhc3MgS3N7Y29uc3RydWN0b3IodCxzLGUsaSl7dGhpcy51cD0hMSx0aGlzLnNlbmQ9aSx0aGlzLnZhbHVlPTAsdGhpcy50eXBlPSJjYyJ9c2V0VmFsdWUodCl7dGhpcy52YWx1ZT10fXVwZGF0ZSh0LHMsZSl7cmV0dXJuIHRoaXMuaWQ9cywhdGhpcy51cCYmdD4wPyh0aGlzLnVwPSEwLHRoaXMuc2VuZCh7dHlwZToiU0lHTkFMX1RSSUdHRVIiLGlkOnMsdGltZTplfSksdGhpcy52YWx1ZSk6KHRoaXMudXA9dD4wLHRoaXMudmFsdWUpfX1jbGFzcyBacyBleHRlbmRzIHl7Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy50eXBlPSJjYyIsdGhpcy52YWx1ZT1zLmlucHV0c1sxXT8/MH1zZXRWYWx1ZSh0KXt0aGlzLnZhbHVlPXR9dXBkYXRlKHQpe3JldHVybiB0aGlzLmlkPXQsdGhpcy52YWx1ZX19Y2xhc3MgWHMgZXh0ZW5kcyB5e2NvbnN0cnVjdG9yKHQscyxlLGkpe3N1cGVyKHQscyxlLGkpLHRoaXMudHlwZT0ibWlkaWNjIix0aGlzLnZhbHVlPXMuaW5wdXRzWzJdPz8tMSx0aGlzLmNoYW5uZWw9LTEsdGhpcy5jY251bWJlcj0tMX1zZXRWYWx1ZSh0KXt0aGlzLnZhbHVlPXR9dXBkYXRlKHQscyl7cmV0dXJuIHRoaXMuY2NudW1iZXI9dCx0aGlzLmNoYW5uZWw9cyx0aGlzLnZhbHVlfX1jbGFzcyBKcyBleHRlbmRzIHl7Y29uc3RydWN0b3IodCxzLGUsaSl7c3VwZXIodCxzLGUsaSksdGhpcy5jbG9ja1Nnbj0hMCx0aGlzLnN0ZXA9MCx0aGlzLmZpcnN0PSEwfXVwZGF0ZSh0LC4uLnMpe3JldHVybiF0aGlzLmNsb2NrU2duJiZ0PjA/KHRoaXMuc3RlcD0odGhpcy5zdGVwKzEpJXMubGVuZ3RoLHRoaXMuY2xvY2tTZ249dD4wLDApOih0aGlzLmNsb2NrU2duPXQ+MCxzW3RoaXMuc3RlcF0pfX1jbGFzcyBRcyBleHRlbmRzIHl7dXBkYXRlKHQsLi4ucyl7Y29uc3QgZT10JXMubGVuZ3RoK3MubGVuZ3RoO3JldHVybiBzW01hdGguZmxvb3IoZSklcy5sZW5ndGhdfX1jbGFzcyB0ZXt1cGRhdGUodCxzLGUsaSxuKXtsZXQgYT11cyh0LHMsZSk7cmV0dXJuIGNzKGEsaSxuKX19Y2xhc3Mgc2V7dXBkYXRlKHQscyxlKXtyZXR1cm4gTWF0aC5taW4oTWF0aC5tYXgodCxzKSxlKX19Y2xhc3MgZWV7Y29uc3RydWN0b3IoKXt0aGlzLmhpPSExfXVwZGF0ZSh0KXtyZXR1cm4hdGhpcy5oaSYmdD4wPyh0aGlzLmhpPSEwLDEpOih0aGlzLmhpJiZ0PD0wJiYodGhpcy5oaT0hMSksMCl9fWNsYXNzIGlle2NvbnN0cnVjdG9yKCl7dGhpcy54MT0wLHRoaXMueDI9MCx0aGlzLnkxPTAsdGhpcy55Mj0wLHRoaXMuYTA9MSx0aGlzLmExPTAsdGhpcy5hMj0wLHRoaXMuYjA9MSx0aGlzLmIxPTAsdGhpcy5iMj0wfXVwZGF0ZSh0PTAscz0wLGU9NTAwLGk9MSxuPTEpe2NvbnN0IGE9MipNYXRoLlBJKmUvc2FtcGxlUmF0ZSxvPU1hdGguc2luKGEpO2k9TWF0aC5wb3coMTAsaS8yMCk7Y29uc3QgYz1vLygyKmkpLGg9TWF0aC5jb3MoYSk7aWYocz09PTApdGhpcy5iMT0xLWgsdGhpcy5iMD10aGlzLmIxLzIsdGhpcy5iMj10aGlzLmIwLHRoaXMuYTA9MStjLHRoaXMuYTE9LTIqaCx0aGlzLmEyPTEtYztlbHNlIGlmKHM9PT0xKXRoaXMuYjA9KDEraCkvMix0aGlzLmIxPS0oMStoKSx0aGlzLmIyPXRoaXMuYjAsdGhpcy5hMD0xK2MsdGhpcy5hMT0tMipoLHRoaXMuYTI9MS1jO2Vsc2UgaWYocz09PTIpdGhpcy5iMD1vLzIsdGhpcy5iMT0wLHRoaXMuYjI9LXRoaXMuYjAsdGhpcy5hMD0xK2MsdGhpcy5hMT0tMipoLHRoaXMuYTI9MS1jO2Vsc2UgaWYocz09PTMpdGhpcy5iMD0xLHRoaXMuYjE9LTIqaCx0aGlzLmIyPTEsdGhpcy5hMD0xK2MsdGhpcy5hMT0tMipoLHRoaXMuYTI9MS1jO2Vsc2UgaWYocz09PTQpdGhpcy5iMD0xLWMsdGhpcy5iMT0tMipoLHRoaXMuYjI9MStjLHRoaXMuYTA9MStjLHRoaXMuYTE9LTIqaCx0aGlzLmEyPTEtYztlbHNlIGlmKHM9PT01KXtjb25zdCB1PU1hdGgucG93KDEwLG4vNDApO3RoaXMuYjA9MStjKnUsdGhpcy5iMT0tMipoLHRoaXMuYjI9MS1jKnUsdGhpcy5hMD0xK2MvdSx0aGlzLmExPS0yKmgsdGhpcy5hMj0xLWMvdX1lbHNlIGlmKHM9PT02KXtjb25zdCB1PU1hdGgucG93KDEwLG4vNDApLGQ9MipNYXRoLnNxcnQodSkqYyxsPSh1LTEpKmgscD0odSsxKSpoO3RoaXMuYjA9dSoodSsxLWwrZCksdGhpcy5iMT0yKnUqKHUtMS1wKSx0aGlzLmIyPXUqKHUrMS1sLWQpLHRoaXMuYTA9dSsxK2wrZCx0aGlzLmExPS0yKih1LTErcCksdGhpcy5hMj11KzErbC1kfWVsc2UgaWYocz09PTcpe2NvbnN0IHU9TWF0aC5wb3coMTAsbi80MCksZD0yKk1hdGguc3FydCh1KSpjLGw9KHUtMSkqaCxwPSh1KzEpKmg7dGhpcy5iMD11Kih1KzErbCtkKSx0aGlzLmIxPS0yKnUqKHUtMStwKSx0aGlzLmIyPXUqKHUrMStsLWQpLHRoaXMuYTA9dSsxLWwrZCx0aGlzLmExPTIqKHUtMS1wKSx0aGlzLmEyPXUrMS1sLWR9dGhpcy5iMC89dGhpcy5hMCx0aGlzLmIxLz10aGlzLmEwLHRoaXMuYjIvPXRoaXMuYTAsdGhpcy5hMS89dGhpcy5hMCx0aGlzLmEyLz10aGlzLmEwLHRoaXMuYTA9MTtjb25zdCBmPXRoaXMuYjAqdCt0aGlzLmIxKnRoaXMueDErdGhpcy5iMip0aGlzLngyLXRoaXMuYTEqdGhpcy55MS10aGlzLmEyKnRoaXMueTI7cmV0dXJuIHRoaXMueDI9dGhpcy54MSx0aGlzLngxPXQsdGhpcy55Mj10aGlzLnkxLHRoaXMueTE9ZixmfX1jb25zdCByZT1PYmplY3QuZnJlZXplKE9iamVjdC5kZWZpbmVQcm9wZXJ0eSh7X19wcm90b19fOm51bGwsQURTUk5vZGU6YnMsQXVkaW9JbjpqcyxBdWRpb05vZGU6eSxCUEY6WXMsQmlxdWFkRmlsdGVyOmllLEJyb3duTm9pc2VPc2M6VnMsQ0M6WnMsQ0xPQ0tfUFBROl90LENMT0NLX1BQUzpncyxDbGlwOnNlLENsb2NrOnZzLENsb2NrRGl2OklzLENsb2NrT3V0OndzLERlbGF5OlNzLERpc3RvcnQ6X3MsRHVzdE9zYzpCcyxGaWx0ZXI6V3MsRm9sZDpHcyxIb2xkOk1zLEltcHVsc2VPc2M6T3MsTGFnOnpzLExjZ05vaXNlOlBzLE1pZGlDQzpYcyxNaWRpRnJlcTpVcyxNaWRpR2F0ZTpIcyxNaWRpSW46YnQsTWlkaVZlbDokcyxOb2lzZU9zYzpUcyxPdXRwdXQ6eHMsUGljazpRcyxQaW5rTm9pc2U6QXMsUHVsc2VPc2M6TnMsUmVtYXA6dGUsU2F3T3NjOkZzLFNjb3BlOkRzLFNlcXVlbmNlOkpzLFNpZGVjaGFpbkNvbXByZXNzb3I6a3MsU2lnbmFsOktzLFNpbmVPc2M6RXMsU2xldzpxcyxTbGlkZTpMcyxUcmlPc2M6UnMsVHJpZzplZSxaYXdPc2M6Q3N9LFN5bWJvbC50b1N0cmluZ1RhZyx7dmFsdWU6Ik1vZHVsZSJ9KSksbmU9bmV3IE1hcChPYmplY3QuZW50cmllcyhyZSkpLFk9MTI4LEQ9TWF0aC5QSSx6PTIqRCxHPTEvc2FtcGxlUmF0ZSx4dD1yPT4xLU1hdGguZXhwKC1HL3IpLGp0PXI9Pk1hdGgucG93KDEwLHIvMjApLFM9KHIsdCxzKT0+TWF0aC5taW4oTWF0aC5tYXgocix0KSxzKSx1dD0ocix0LHMpPT5zKih0LXIpK3IsYj0ocix0KT0+clt0XT8/clswXSxRPXI9PnItTWF0aC5mbG9vcihyKSx0dD1yPT5yfDAsc3Q9cj0+dHQocisuNSksYWU9cj0+dHQocisxKSxIdD1yPT5yLXR0KHIpLGo9cj0+e2NvbnN0IHQ9cioqMjtyZXR1cm4gciooMjcrdCkvKDI3KzkqdCl9LFV0PShyLHQpPT57aWYocjwyKXJldHVybiBpPT4wO2NvbnN0IHM9dC8oci0xKSxlPXQqLjU7cmV0dXJuIGk9Pmkqcy1lfSxldD0ocix0KT0+cipNYXRoLnBvdygyLHQvMTIpO2Z1bmN0aW9uIG9lKHIsdCl7dD1NYXRoLm1pbih0LDEtdCk7Y29uc3Qgcz0xL3Q7cmV0dXJuIHI8dD8ocio9cywyKnItcioqMi0xKTpyPjEtdD8ocj0oci0xKSpzLHIqKjIrMipyKzEpOjB9Y29uc3QgeXQ9e3RyaShyLHQ9LjUpe2NvbnN0IHM9MS10O3JldHVybiByPj10PzEvcy1yL3M6ci90fSxzaW5lKHIpe3JldHVybiBNYXRoLnNpbih6KnIpKi41Ky41fSxyYW1wKHIpe3JldHVybiByfSxzYXcocil7cmV0dXJuIDEtcn0sc3F1YXJlKHIsdD0uNSl7cmV0dXJuIHI+PXQ/MDoxfSxjdXN0b20ocix0PVswLDFdKXtjb25zdCBzPXQubGVuZ3RoLTEsZT1NYXRoLmZsb29yKHIqcyksaT0xL3Msbj1TKHRbZV0sMCwxKSxvPVModFtlKzFdLDAsMSksYz1uLGg9MCxmPWk7cmV0dXJuKG8tYykvKGYtaCkqKHItaSplKStufSxzYXdibGVwKHIsdCl7cmV0dXJuIDIqci0xLW9lKHIsdCl9fSxoZT1PYmplY3Qua2V5cyh5dCk7Y2xhc3MgY2UgZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7c3RhdGljIGdldCBwYXJhbWV0ZXJEZXNjcmlwdG9ycygpe3JldHVyblt7bmFtZToiYmVnaW4iLGRlZmF1bHRWYWx1ZTowfSx7bmFtZToidGltZSIsZGVmYXVsdFZhbHVlOjB9LHtuYW1lOiJlbmQiLGRlZmF1bHRWYWx1ZTowfSx7bmFtZToiZnJlcXVlbmN5IixkZWZhdWx0VmFsdWU6LjV9LHtuYW1lOiJza2V3IixkZWZhdWx0VmFsdWU6LjV9LHtuYW1lOiJkZXB0aCIsZGVmYXVsdFZhbHVlOjF9LHtuYW1lOiJwaGFzZW9mZnNldCIsZGVmYXVsdFZhbHVlOjB9LHtuYW1lOiJzaGFwZSIsZGVmYXVsdFZhbHVlOjB9LHtuYW1lOiJjdXJ2ZSIsZGVmYXVsdFZhbHVlOjF9LHtuYW1lOiJkY29mZnNldCIsZGVmYXVsdFZhbHVlOjB9LHtuYW1lOiJtaW4iLGRlZmF1bHRWYWx1ZTotMWU5fSx7bmFtZToibWF4IixkZWZhdWx0VmFsdWU6MWU5fV19Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMucGhhc2V9aW5jcmVtZW50UGhhc2UodCl7dGhpcy5waGFzZSs9dCx0aGlzLnBoYXNlPjEmJih0aGlzLnBoYXNlPXRoaXMucGhhc2UtMSl9cHJvY2Vzcyh0LHMsZSl7Y29uc3QgaT1lLmJlZ2luWzBdLG49ZS5lbmRbMF07aWYoY3VycmVudFRpbWU+PW4pcmV0dXJuITE7aWYoY3VycmVudFRpbWU8PWkpcmV0dXJuITA7Y29uc3QgYT1zWzBdLG89ZS5mcmVxdWVuY3lbMF0sYz1lLnRpbWVbMF0saD1lLmRlcHRoWzBdLGY9ZS5za2V3WzBdLHU9ZS5waGFzZW9mZnNldFswXSxkPWUuY3VydmVbMF0sbD1lLmRjb2Zmc2V0WzBdLHA9ZS5taW5bMF0sbT1lLm1heFswXSxJPWhlW2Uuc2hhcGVbMF1dLHc9YVswXS5sZW5ndGg/PzA7dGhpcy5waGFzZT09bnVsbCYmKHRoaXMucGhhc2U9SHQoYypvK3UpKTtjb25zdCB2PW8qRztmb3IobGV0IE09MDtNPHc7TSsrKXtmb3IobGV0IFA9MDtQPGEubGVuZ3RoO1ArKyl7bGV0IGc9KHl0W0ldKHRoaXMucGhhc2UsZikrbCkqaDtnPU1hdGgucG93KGcsZCksYVtQXVtNXT1TKGcscCxtKX10aGlzLmluY3JlbWVudFBoYXNlKHYpfXJldHVybiEwfX1yZWdpc3RlclByb2Nlc3NvcigibGZvLXByb2Nlc3NvciIsY2UpO2NsYXNzIHVlIGV4dGVuZHMgQXVkaW9Xb3JrbGV0UHJvY2Vzc29ye3N0YXRpYyBnZXQgcGFyYW1ldGVyRGVzY3JpcHRvcnMoKXtyZXR1cm5be25hbWU6ImNvYXJzZSIsZGVmYXVsdFZhbHVlOjF9XX1jb25zdHJ1Y3Rvcigpe3N1cGVyKCksdGhpcy5zdGFydGVkPSExfXByb2Nlc3ModCxzLGUpe2NvbnN0IGk9dFswXSxuPXNbMF0sYT1pWzBdIT09dm9pZCAwO2lmKHRoaXMuc3RhcnRlZCYmIWEpcmV0dXJuITE7dGhpcy5zdGFydGVkPWE7bGV0IG89ZS5jb2Fyc2VbMF0/PzA7bz1NYXRoLm1heCgxLG8pO2ZvcihsZXQgYz0wO2M8WTtjKyspZm9yKGxldCBoPTA7aDxpLmxlbmd0aDtoKyspbltoXVtjXT1jJW89PT0wP2lbaF1bY106bltoXVtjLTFdO3JldHVybiEwfX1yZWdpc3RlclByb2Nlc3NvcigiY29hcnNlLXByb2Nlc3NvciIsdWUpO2NsYXNzIGxlIGV4dGVuZHMgQXVkaW9Xb3JrbGV0UHJvY2Vzc29ye3N0YXRpYyBnZXQgcGFyYW1ldGVyRGVzY3JpcHRvcnMoKXtyZXR1cm5be25hbWU6ImNydXNoIixkZWZhdWx0VmFsdWU6MH1dfWNvbnN0cnVjdG9yKCl7c3VwZXIoKSx0aGlzLnN0YXJ0ZWQ9ITF9cHJvY2Vzcyh0LHMsZSl7Y29uc3QgaT10WzBdLG49c1swXSxhPWlbMF0hPT12b2lkIDA7aWYodGhpcy5zdGFydGVkJiYhYSlyZXR1cm4hMTt0aGlzLnN0YXJ0ZWQ9YTtsZXQgbz1lLmNydXNoWzBdPz84O289TWF0aC5tYXgoMSxvKTtmb3IobGV0IGM9MDtjPFk7YysrKWZvcihsZXQgaD0wO2g8aS5sZW5ndGg7aCsrKXtjb25zdCBmPU1hdGgucG93KDIsby0xKTtuW2hdW2NdPU1hdGgucm91bmQoaVtoXVtjXSpmKS9mfXJldHVybiEwfX1yZWdpc3RlclByb2Nlc3NvcigiY3J1c2gtcHJvY2Vzc29yIixsZSk7Y2xhc3MgZmUgZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7c3RhdGljIGdldCBwYXJhbWV0ZXJEZXNjcmlwdG9ycygpe3JldHVyblt7bmFtZToic2hhcGUiLGRlZmF1bHRWYWx1ZTowfSx7bmFtZToicG9zdGdhaW4iLGRlZmF1bHRWYWx1ZToxfV19Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMuc3RhcnRlZD0hMX1wcm9jZXNzKHQscyxlKXtjb25zdCBpPXRbMF0sbj1zWzBdLGE9aVswXSE9PXZvaWQgMDtpZih0aGlzLnN0YXJ0ZWQmJiFhKXJldHVybiExO3RoaXMuc3RhcnRlZD1hO2xldCBvPWUuc2hhcGVbMF07bz1vPDE/bzouOTk5OTk5OTk5NixvPTIqby8oMS1vKTtjb25zdCBjPU1hdGgubWF4KC4wMDEsTWF0aC5taW4oMSxlLnBvc3RnYWluWzBdKSk7Zm9yKGxldCBoPTA7aDxZO2grKylmb3IobGV0IGY9MDtmPGkubGVuZ3RoO2YrKyluW2ZdW2hdPSgxK28pKmlbZl1baF0vKDErbypNYXRoLmFicyhpW2ZdW2hdKSkqYztyZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoInNoYXBlLXByb2Nlc3NvciIsZmUpO2NsYXNzICR0e2NvbnN0cnVjdG9yKCl7RHQodGhpcywiczAiLDApO0R0KHRoaXMsInMxIiwwKX11cGRhdGUodCxzLGU9MCl7ZT1TKGUsMCwxKSxzPVMocywwLHNhbXBsZVJhdGUvMi0xKTtjb25zdCBpPVMoMipNYXRoLnNpbihzKkQqRyksMCwxLjE0KSxhPTEtTWF0aC5wb3coLjUsOCplKzEpKmk7cmV0dXJuIHRoaXMuczA9YSp0aGlzLnMwLWkqdGhpcy5zMStpKnQsdGhpcy5zMT1hKnRoaXMuczEraSp0aGlzLnMwLHRoaXMuczF9fWNsYXNzIGRlIGV4dGVuZHMgQXVkaW9Xb3JrbGV0UHJvY2Vzc29ye3N0YXRpYyBnZXQgcGFyYW1ldGVyRGVzY3JpcHRvcnMoKXtyZXR1cm5be25hbWU6InZhbHVlIixkZWZhdWx0VmFsdWU6LjV9XX1jb25zdHJ1Y3Rvcigpe3N1cGVyKCksdGhpcy5maWx0ZXJzPVtuZXcgJHQsbmV3ICR0XX1wcm9jZXNzKHQscyxlKXtjb25zdCBpPXRbMF0sbj1zWzBdLGE9aVswXSE9PXZvaWQgMDt0aGlzLnN0YXJ0ZWQ9YTtjb25zdCBvPVMoZS52YWx1ZVswXSwwLDEpO2xldCBjPSJub25lIixoLGY9MTtvPi41MT8oYz0iaGlwYXNzIixmPShvLS41KSoyKTpvPC40OSYmKGM9ImxvcGFzcyIsZj1vKjIpLGg9TWF0aC5wb3coZioxMSw0KTtmb3IobGV0IHU9MDt1PGkubGVuZ3RoO3UrKylmb3IobGV0IGQ9MDtkPFk7ZCsrKWM9PSJub25lIj9uW3VdW2RdPWlbdV1bZF06KHRoaXMuZmlsdGVyc1t1XS51cGRhdGUoaVt1XVtkXSxoLC4xKSxjPT09ImxvcGFzcyI/blt1XVtkXT10aGlzLmZpbHRlcnNbdV0uczE6Yz09PSJoaXBhc3MiP25bdV1bZF09aVt1XVtkXS10aGlzLmZpbHRlcnNbdV0uczE6blt1XVtkXT1pW3VdW2RdKTtyZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoImRqZi1wcm9jZXNzb3IiLGRlKTtjbGFzcyBwZSBleHRlbmRzIEF1ZGlvV29ya2xldFByb2Nlc3NvcntzdGF0aWMgZ2V0IHBhcmFtZXRlckRlc2NyaXB0b3JzKCl7cmV0dXJuW3tuYW1lOiJmcmVxdWVuY3kiLGRlZmF1bHRWYWx1ZTo1MDB9LHtuYW1lOiJxIixkZWZhdWx0VmFsdWU6MX0se25hbWU6ImRyaXZlIixkZWZhdWx0VmFsdWU6LjY5fV19Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMuc3RhcnRlZD0hMSx0aGlzLnAwPVswLDBdLHRoaXMucDE9WzAsMF0sdGhpcy5wMj1bMCwwXSx0aGlzLnAzPVswLDBdLHRoaXMucDMyPVswLDBdLHRoaXMucDMzPVswLDBdLHRoaXMucDM0PVswLDBdfXByb2Nlc3ModCxzLGUpe2NvbnN0IGk9dFswXSxuPXNbMF0sYT1pWzBdIT09dm9pZCAwO2lmKHRoaXMuc3RhcnRlZCYmIWEpcmV0dXJuITE7dGhpcy5zdGFydGVkPWE7Y29uc3Qgbz1lLnFbMF0sYz1TKE1hdGguZXhwKGUuZHJpdmVbMF0pLC4xLDJlMyk7bGV0IGg9ZS5mcmVxdWVuY3lbMF07aD1oKnoqRyxoPWg+MT8xOmg7Y29uc3QgZj1NYXRoLm1pbig4LG8qLjEzKTtsZXQgdT0xL2MqTWF0aC5taW4oMS43NSwxK2YpO2ZvcihsZXQgZD0wO2Q8WTtkKyspZm9yKGxldCBsPTA7bDxpLmxlbmd0aDtsKyspe2NvbnN0IHA9dGhpcy5wM1tsXSouMzYwODkxK3RoaXMucDMyW2xdKi40MTcyOSt0aGlzLnAzM1tsXSouMTc3ODk2K3RoaXMucDM0W2xdKi4wNDM5NzI1O3RoaXMucDM0W2xdPXRoaXMucDMzW2xdLHRoaXMucDMzW2xdPXRoaXMucDMyW2xdLHRoaXMucDMyW2xdPXRoaXMucDNbbF0sdGhpcy5wMFtsXSs9KGooaVtsXVtkXSpjLWYqcCktaih0aGlzLnAwW2xdKSkqaCx0aGlzLnAxW2xdKz0oaih0aGlzLnAwW2xdKS1qKHRoaXMucDFbbF0pKSpoLHRoaXMucDJbbF0rPShqKHRoaXMucDFbbF0pLWoodGhpcy5wMltsXSkpKmgsdGhpcy5wM1tsXSs9KGoodGhpcy5wMltsXSktaih0aGlzLnAzW2xdKSkqaCxuW2xdW2RdPXAqdX1yZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoImxhZGRlci1wcm9jZXNzb3IiLHBlKTtjbGFzcyBtZSBleHRlbmRzIEF1ZGlvV29ya2xldFByb2Nlc3NvcntzdGF0aWMgZ2V0IHBhcmFtZXRlckRlc2NyaXB0b3JzKCl7cmV0dXJuW3tuYW1lOiJkaXN0b3J0IixkZWZhdWx0VmFsdWU6MH0se25hbWU6InBvc3RnYWluIixkZWZhdWx0VmFsdWU6MX1dfWNvbnN0cnVjdG9yKHtwcm9jZXNzb3JPcHRpb25zOnR9KXtzdXBlcigpLHRoaXMuc3RhcnRlZD0hMSx0aGlzLmFsZ29yaXRobT1ocyh0LmFsZ29yaXRobSl9cHJvY2Vzcyh0LHMsZSl7Y29uc3QgaT10WzBdLG49c1swXSxhPWlbMF0hPT12b2lkIDA7aWYodGhpcy5zdGFydGVkJiYhYSlyZXR1cm4hMTt0aGlzLnN0YXJ0ZWQ9YTtmb3IobGV0IG89MDtvPFk7bysrKXtjb25zdCBjPVMoYihlLnBvc3RnYWluLG8pLC4wMDEsMSksaD1NYXRoLmV4cG0xKGIoZS5kaXN0b3J0LG8pKTtmb3IobGV0IGY9MDtmPGkubGVuZ3RoO2YrKyl7Y29uc3QgdT1pW2ZdW29dO25bZl1bb109Yyp0aGlzLmFsZ29yaXRobSh1LGgpfX1yZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoImRpc3RvcnQtcHJvY2Vzc29yIixtZSk7Y2xhc3MgZ2UgZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMucG9ydC5vbm1lc3NhZ2U9dD0+e2NvbnN0e3R5cGU6cyxwYXlsb2FkOmV9PXQuZGF0YXx8e307cz09PSJpbml0aWFsaXplIiYmdGhpcy5pbml0aWFsaXplKGUpfSx0aGlzLmluaXRpYWxpemUoKX1pbml0aWFsaXplKHQpe3RoaXMucGhhc2U9W119c3RhdGljIGdldCBwYXJhbWV0ZXJEZXNjcmlwdG9ycygpe3JldHVyblt7bmFtZToiYmVnaW4iLGRlZmF1bHRWYWx1ZTotMSxtYXg6TnVtYmVyLlBPU0lUSVZFX0lORklOSVRZLG1pbjotMX0se25hbWU6ImVuZCIsZGVmYXVsdFZhbHVlOi0xLG1heDpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFksbWluOi0xfSx7bmFtZToiZnJlcXVlbmN5IixkZWZhdWx0VmFsdWU6NDQwLG1pbjpOdW1iZXIuRVBTSUxPTn0se25hbWU6InBhbnNwcmVhZCIsZGVmYXVsdFZhbHVlOi40LG1pbjowLG1heDoxfSx7bmFtZToiZnJlcXNwcmVhZCIsZGVmYXVsdFZhbHVlOi4yLG1pbjowfSx7bmFtZToiZGV0dW5lIixkZWZhdWx0VmFsdWU6MCxtaW46MH0se25hbWU6InZvaWNlcyIsZGVmYXVsdFZhbHVlOjUsbWluOjEsYXV0b21hdGlvblJhdGU6ImstcmF0ZSJ9XX1wcm9jZXNzKHQscyxlKXtjb25zdCBpPWUuYmVnaW5bMF0sbj1lLmVuZFswXSxhPWk+PTAsbz1uPj0wLGM9byYmY3VycmVudFRpbWU+PW4rLjUsaD1vJiZjdXJyZW50VGltZT49bixmPWN1cnJlbnRUaW1lPD1pO2lmKGMpcmV0dXJuITE7aWYoaHx8Znx8IWEpcmV0dXJuITA7Y29uc3QgdT1zWzBdLGQ9ZS52b2ljZXNbMF07Zm9yKGxldCBsPTA7bDx1WzBdLmxlbmd0aDtsKyspe2NvbnN0IHA9YihlLmRldHVuZSxsKSxtPWIoZS5mcmVxc3ByZWFkLGwpLEk9YihlLnBhbnNwcmVhZCxsKSouNSsuNTtsZXQgdz1NYXRoLnNxcnQoMS1JKSx2PU1hdGguc3FydChJKSxNPWIoZS5mcmVxdWVuY3ksbCk7TT1ldChNLHAvMTAwKTtjb25zdCBQPVV0KGQsbSk7Zm9yKGxldCBnPTA7ZzxkO2crKyl7Y29uc3QgVD1ldChNLFAoZykpLEE9UShUKkcpO3RoaXMucGhhc2VbZ109dGhpcy5waGFzZVtnXT8/TWF0aC5yYW5kb20oKTtjb25zdCBWPXl0LnNhd2JsZXAodGhpcy5waGFzZVtnXSxBKTt1WzBdW2xdKz1WKncsdVsxXVtsXSs9Vip2O2xldCBPPXRoaXMucGhhc2VbZ10rQTtPPj0xJiYoTy09MSksdGhpcy5waGFzZVtnXT1PO2NvbnN0IE49dzt3PXYsdj1OfX1yZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoInN1cGVyc2F3LW9zY2lsbGF0b3IiLGdlKTtjb25zdCBiZT0yMDQ4LFB0PW5ldyBNYXA7ZnVuY3Rpb24gdmUocil7aWYoIVB0LmhhcyhyKSl7Y29uc3QgdD1uZXcgRmxvYXQzMkFycmF5KHIpO2ZvcihsZXQgcz0wO3M8cjtzKyspdFtzXT0uNSooMS1NYXRoLmNvcyh6KnMvcikpO1B0LnNldChyLHQpfXJldHVybiBQdC5nZXQocil9Y2xhc3MgSWUgZXh0ZW5kcyBYe3N0YXRpYyBnZXQgcGFyYW1ldGVyRGVzY3JpcHRvcnMoKXtyZXR1cm5be25hbWU6InBpdGNoRmFjdG9yIixkZWZhdWx0VmFsdWU6MX1dfWNvbnN0cnVjdG9yKHQpe3QucHJvY2Vzc29yT3B0aW9ucz17YmxvY2tTaXplOmJlfSxzdXBlcih0KSx0aGlzLnRpbWVDdXJzb3I9MCx0aGlzLmZmdFNpemU9dGhpcy5ibG9ja1NpemUsdGhpcy5pbnZmZnRTaXplPTEvdGhpcy5mZnRTaXplLHRoaXMuaGFubldpbmRvdz12ZSh0aGlzLmZmdFNpemUpLHRoaXMuZmZ0PW5ldyBRdCh0aGlzLmZmdFNpemUpLHRoaXMuZnJlcUNvbXBsZXhCdWZmZXI9dGhpcy5mZnQuY3JlYXRlQ29tcGxleEFycmF5KCksdGhpcy5mcmVxQ29tcGxleEJ1ZmZlclNoaWZ0ZWQ9dGhpcy5mZnQuY3JlYXRlQ29tcGxleEFycmF5KCksdGhpcy50aW1lQ29tcGxleEJ1ZmZlcj10aGlzLmZmdC5jcmVhdGVDb21wbGV4QXJyYXkoKSx0aGlzLm1hZ25pdHVkZXM9bmV3IEZsb2F0MzJBcnJheSh0aGlzLmZmdFNpemUvMisxKSx0aGlzLnBlYWtJbmRleGVzPW5ldyBJbnQzMkFycmF5KHRoaXMubWFnbml0dWRlcy5sZW5ndGgpLHRoaXMubmJQZWFrcz0wfXByb2Nlc3NPTEEodCxzLGUpe2xldCBpPWUucGl0Y2hGYWN0b3JbZS5waXRjaEZhY3Rvci5sZW5ndGgtMV07aTwwJiYoaT1pKi4yNSksaT1NYXRoLm1heCgwLGkrMSk7Zm9yKGxldCBuPTA7bjx0aGlzLm5iSW5wdXRzO24rKylmb3IobGV0IGE9MDthPHRbbl0ubGVuZ3RoO2ErKyl7Y29uc3Qgbz10W25dW2FdLGM9c1tuXVthXTt0aGlzLmFwcGx5SGFubldpbmRvdyhvKSx0aGlzLmZmdC5yZWFsVHJhbnNmb3JtKHRoaXMuZnJlcUNvbXBsZXhCdWZmZXIsbyksdGhpcy5jb21wdXRlTWFnbml0dWRlcygpLHRoaXMuZmluZFBlYWtzKCksdGhpcy5zaGlmdFBlYWtzKGkpLHRoaXMuZmZ0LmNvbXBsZXRlU3BlY3RydW0odGhpcy5mcmVxQ29tcGxleEJ1ZmZlclNoaWZ0ZWQpLHRoaXMuZmZ0LmludmVyc2VUcmFuc2Zvcm0odGhpcy50aW1lQ29tcGxleEJ1ZmZlcix0aGlzLmZyZXFDb21wbGV4QnVmZmVyU2hpZnRlZCksdGhpcy5mZnQuZnJvbUNvbXBsZXhBcnJheSh0aGlzLnRpbWVDb21wbGV4QnVmZmVyLGMpLHRoaXMuYXBwbHlIYW5uV2luZG93KGMpfXRoaXMudGltZUN1cnNvcis9dGhpcy5ob3BTaXplfWFwcGx5SGFubldpbmRvdyh0KXtmb3IobGV0IHM9MDtzPHRoaXMuYmxvY2tTaXplO3MrKyl0W3NdKj10aGlzLmhhbm5XaW5kb3dbc10qMS42Mn1jb21wdXRlTWFnbml0dWRlcygpe2xldCB0PTAscz0wO2Zvcig7dDx0aGlzLm1hZ25pdHVkZXMubGVuZ3RoOyl7Y29uc3QgZT10aGlzLmZyZXFDb21wbGV4QnVmZmVyW3NdLGk9dGhpcy5mcmVxQ29tcGxleEJ1ZmZlcltzKzFdO3RoaXMubWFnbml0dWRlc1t0XT1lKioyK2kqKjIsdCs9MSxzKz0yfX1maW5kUGVha3MoKXt0aGlzLm5iUGVha3M9MDtsZXQgdD0yO2NvbnN0IHM9dGhpcy5tYWduaXR1ZGVzLmxlbmd0aC0yO2Zvcig7dDxzOyl7Y29uc3QgZT10aGlzLm1hZ25pdHVkZXNbdF07aWYodGhpcy5tYWduaXR1ZGVzW3QtMV0+PWV8fHRoaXMubWFnbml0dWRlc1t0LTJdPj1lKXt0Kys7Y29udGludWV9aWYodGhpcy5tYWduaXR1ZGVzW3QrMV0+PWV8fHRoaXMubWFnbml0dWRlc1t0KzJdPj1lKXt0Kys7Y29udGludWV9dGhpcy5wZWFrSW5kZXhlc1t0aGlzLm5iUGVha3NdPXQsdGhpcy5uYlBlYWtzKyssdCs9Mn19c2hpZnRQZWFrcyh0KXt0aGlzLmZyZXFDb21wbGV4QnVmZmVyU2hpZnRlZC5maWxsKDApO2ZvcihsZXQgcz0wO3M8dGhpcy5uYlBlYWtzO3MrKyl7Y29uc3QgZT10aGlzLnBlYWtJbmRleGVzW3NdLGk9c3QoZSp0KTtpZihpPnRoaXMubWFnbml0dWRlcy5sZW5ndGgpYnJlYWs7bGV0IG49MCxhPXRoaXMuZmZ0U2l6ZTtzPjAmJihuPWUtc3QoKGUtdGhpcy5wZWFrSW5kZXhlc1tzLTFdKS8yKSksczx0aGlzLm5iUGVha3MtMSYmKGE9ZSthZSgodGhpcy5wZWFrSW5kZXhlc1tzKzFdLWUpLzIpKTtjb25zdCBvPW4tZSxjPWEtZSxoPXoqdGhpcy5pbnZmZnRTaXplKihpLWUpLGY9TWF0aC5jb3MoaCp0aGlzLnRpbWVDdXJzb3IpLHU9TWF0aC5zaW4oaCp0aGlzLnRpbWVDdXJzb3IpO2ZvcihsZXQgZD1vO2Q8YztkKyspe2NvbnN0IGw9ZStkLHA9aStkO2lmKHA+PXRoaXMubWFnbml0dWRlcy5sZW5ndGgpYnJlYWs7Y29uc3QgbT0yKmwsST1tKzEsdz10aGlzLmZyZXFDb21wbGV4QnVmZmVyW21dLHY9dGhpcy5mcmVxQ29tcGxleEJ1ZmZlcltJXSxNPXcqZi12KnUsUD13KnUrdipmLGc9MipwLFQ9ZysxO3RoaXMuZnJlcUNvbXBsZXhCdWZmZXJTaGlmdGVkW2ddKz1NLHRoaXMuZnJlcUNvbXBsZXhCdWZmZXJTaGlmdGVkW1RdKz1QfX19fXJlZ2lzdGVyUHJvY2Vzc29yKCJwaGFzZS12b2NvZGVyLXByb2Nlc3NvciIsSWUpO2NsYXNzIHdlIGV4dGVuZHMgQXVkaW9Xb3JrbGV0UHJvY2Vzc29ye2NvbnN0cnVjdG9yKCl7c3VwZXIoKSx0aGlzLnBoaT0tRCx0aGlzLlkwPTAsdGhpcy5ZMT0wLHRoaXMuUFc9RCx0aGlzLkI9Mi4zLHRoaXMuZHBoaWY9MCx0aGlzLmVudmY9MH1zdGF0aWMgZ2V0IHBhcmFtZXRlckRlc2NyaXB0b3JzKCl7cmV0dXJuW3tuYW1lOiJiZWdpbiIsZGVmYXVsdFZhbHVlOjAsbWF4Ok51bWJlci5QT1NJVElWRV9JTkZJTklUWSxtaW46MH0se25hbWU6ImVuZCIsZGVmYXVsdFZhbHVlOjAsbWF4Ok51bWJlci5QT1NJVElWRV9JTkZJTklUWSxtaW46MH0se25hbWU6ImZyZXF1ZW5jeSIsZGVmYXVsdFZhbHVlOjQ0MCxtaW46TnVtYmVyLkVQU0lMT059LHtuYW1lOiJkZXR1bmUiLGRlZmF1bHRWYWx1ZTowLG1pbjpOdW1iZXIuTkVHQVRJVkVfSU5GSU5JVFksbWF4Ok51bWJlci5QT1NJVElWRV9JTkZJTklUWX0se25hbWU6InB1bHNld2lkdGgiLGRlZmF1bHRWYWx1ZToxLG1pbjowLG1heDpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFl9XX1wcm9jZXNzKHQscyxlKXtpZih0aGlzLmRpc2Nvbm5lY3RlZClyZXR1cm4hMTtpZihjdXJyZW50VGltZTw9ZS5iZWdpblswXSlyZXR1cm4hMDtpZihjdXJyZW50VGltZT49ZS5lbmRbMF0pcmV0dXJuITE7Y29uc3QgaT1zWzBdO2xldCBuPTEsYTtmb3IobGV0IG89MDtvPChpWzBdLmxlbmd0aD8/MCk7bysrKXtjb25zdCBjPSgxLVMoYihlLnB1bHNld2lkdGgsbyksLS45OSwuOTkpKSpELGg9YihlLmRldHVuZSxvKSxmPWV0KGIoZS5mcmVxdWVuY3ksbyksaC8xMDApO2E9Zip6KkcsdGhpcy5kcGhpZis9LjEqKGEtdGhpcy5kcGhpZiksbio9Ljk5OTgsdGhpcy5lbnZmKz0uMSoobi10aGlzLmVudmYpLHRoaXMuQj0yLjMqKDEtMWUtNCpmKSx0aGlzLkI8MCYmKHRoaXMuQj0wKSx0aGlzLnBoaSs9dGhpcy5kcGhpZix0aGlzLnBoaT49RCYmKHRoaXMucGhpLT16KTtsZXQgdT1NYXRoLmNvcyh0aGlzLnBoaSt0aGlzLkIqdGhpcy5ZMCk7dGhpcy5ZMD0uNSoodSt0aGlzLlkwKTtsZXQgZD1NYXRoLmNvcyh0aGlzLnBoaSt0aGlzLkIqdGhpcy5ZMStjKTt0aGlzLlkxPS41KihkK3RoaXMuWTEpO2ZvcihsZXQgbD0wO2w8aS5sZW5ndGg7bCsrKWlbbF1bb109LjE1Kih1LWQpKnRoaXMuZW52Zn1yZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoInB1bHNlLW9zY2lsbGF0b3IiLHdlKTtjb25zdCBUdD17Yml0QzpmdW5jdGlvbihyLHQscyl7cmV0dXJuIHImdD9zOjB9LGJyOmZ1bmN0aW9uKHIsdD04KXtpZih0PjMyKXRocm93IG5ldyBFcnJvcigiYnIoKSBTaXplIGNhbm5vdCBiZSBncmVhdGVyIHRoYW4gMzIiKTtsZXQgcz0wO2ZvcihsZXQgZT0wO2U8dDtlKyspc3w9VHQuYml0QyhyLDE8PGUsMTw8dC0oZSsxKSk7cmV0dXJuIHN9LHNpbmY6ZnVuY3Rpb24ocil7cmV0dXJuIE1hdGguc2luKHIqRC8xMjgpfSxjb3NmOmZ1bmN0aW9uKHIpe3JldHVybiBNYXRoLmNvcyhyKkQvMTI4KX0sdGFuZjpmdW5jdGlvbihyKXtyZXR1cm4gTWF0aC50YW4ocipELzEyOCl9LHJlZ0c6ZnVuY3Rpb24ocix0KXtyZXR1cm4gdC50ZXN0KHIudG9TdHJpbmcoMikpfX07bGV0IGx0LEJ0O2Z1bmN0aW9uIFNlKHIpe2lmKGx0PT1udWxsKXtsdD1PYmplY3QuZ2V0T3duUHJvcGVydHlOYW1lcyhNYXRoKSxCdD1sdC5tYXAoZT0+TWF0aFtlXSk7Y29uc3QgdD1PYmplY3QuZ2V0T3duUHJvcGVydHlOYW1lcyhUdCkscz10Lm1hcChlPT5UdFtlXSk7bHQucHVzaCgiaW50Iiwid2luZG93IiwuLi50KSxCdC5wdXNoKE1hdGguZmxvb3IsZ2xvYmFsVGhpcywuLi5zKX1yZXR1cm4gbmV3IEZ1bmN0aW9uKC4uLmx0LCJ0IixgcmV0dXJuIDAsCiR7cnx8MH07YCkuYmluZChnbG9iYWxUaGlzLC4uLkJ0KX1jbGFzcyBfZSBleHRlbmRzIEF1ZGlvV29ya2xldFByb2Nlc3Nvcntjb25zdHJ1Y3Rvcigpe3N1cGVyKCksdGhpcy5wb3J0Lm9ubWVzc2FnZT10PT57bGV0e2NvZGVUZXh0OnN9PXQuZGF0YTtjb25zdHtieXRlQmVhdFN0YXJ0VGltZTplfT10LmRhdGE7ZSE9bnVsbCYmKHRoaXMudD0wLHRoaXMuaW5pdGlhbE9mZnNldD1NYXRoLmZsb29yKGUpKSxzPXMudHJpbSgpLnJlcGxhY2UoL15ldmFsXCh1bmVzY2FwZVwoZXNjYXBlKD86YHxcKCd8XCgifFwoYCkoLio/KSg/OmB8J1wpfCJcKXxgXCkpLnJlcGxhY2VcKFwvdVwoXC5cLlwpXC9nLFsiJ2BdXCQxJVsiJ2BdXClcKVwpJC8sKGksbik9PnVuZXNjYXBlKGVzY2FwZShuKS5yZXBsYWNlKC91KC4uKS9nLCIkMSUiKSkpLHRoaXMuZnVuYz1TZShzKX0sdGhpcy5pbml0aWFsT2Zmc2V0PTAsdGhpcy50PW51bGwsdGhpcy5mdW5jPW51bGx9c3RhdGljIGdldCBwYXJhbWV0ZXJEZXNjcmlwdG9ycygpe3JldHVyblt7bmFtZToiYmVnaW4iLGRlZmF1bHRWYWx1ZTowLG1heDpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFksbWluOjB9LHtuYW1lOiJmcmVxdWVuY3kiLGRlZmF1bHRWYWx1ZTo0NDAsbWluOk51bWJlci5FUFNJTE9OfSx7bmFtZToiZGV0dW5lIixkZWZhdWx0VmFsdWU6MCxtaW46TnVtYmVyLk5FR0FUSVZFX0lORklOSVRZLG1heDpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFl9LHtuYW1lOiJlbmQiLGRlZmF1bHRWYWx1ZTowLG1heDpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFksbWluOjB9XX1wcm9jZXNzKHQscyxlKXtpZih0aGlzLmRpc2Nvbm5lY3RlZClyZXR1cm4hMTtpZihjdXJyZW50VGltZTw9ZS5iZWdpblswXSlyZXR1cm4hMDtpZihjdXJyZW50VGltZT49ZS5lbmRbMF0pcmV0dXJuITE7dGhpcy50PT1udWxsJiYodGhpcy50PWUuYmVnaW5bMF0qc2FtcGxlUmF0ZSk7Y29uc3QgaT1zWzBdLG49MjU2Kkc7Zm9yKGxldCBhPTA7YTxpWzBdLmxlbmd0aDthKyspe2NvbnN0IG89YihlLmRldHVuZSxhKSxjPWV0KGIoZS5mcmVxdWVuY3ksYSksby8xMDApLGg9bipjKnRoaXMudCt0aGlzLmluaXRpYWxPZmZzZXQsdT0odGhpcy5mdW5jKGgpJjI1NSkvMTI3LjUtMSxkPVModSouMiwtLjQsLjQpO2ZvcihsZXQgbD0wO2w8aS5sZW5ndGg7bCsrKWlbbF1bYV09ZDt0aGlzLnQrK31yZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoImJ5dGUtYmVhdC1wcm9jZXNzb3IiLF9lKTtjbGFzcyBNZSBleHRlbmRzIEF1ZGlvV29ya2xldFByb2Nlc3NvcntzdGF0aWMgZ2V0IHBhcmFtZXRlckRlc2NyaXB0b3JzKCl7cmV0dXJuW3tuYW1lOiJiZWdpbiIsZGVmYXVsdFZhbHVlOjB9LHtuYW1lOiJlbmQiLGRlZmF1bHRWYWx1ZTowfSx7bmFtZToiYXR0YWNrIixkZWZhdWx0VmFsdWU6LjAwNSxtaW5WYWx1ZTowfSx7bmFtZToiZGVjYXkiLGRlZmF1bHRWYWx1ZTouMTQsbWluVmFsdWU6MH0se25hbWU6InN1c3RhaW4iLGRlZmF1bHRWYWx1ZTowLG1pblZhbHVlOjAsbWF4VmFsdWU6MX0se25hbWU6InJlbGVhc2UiLGRlZmF1bHRWYWx1ZTouMSxtaW5WYWx1ZTowfSx7bmFtZToiYXR0YWNrQ3VydmUiLGRlZmF1bHRWYWx1ZTowLG1pblZhbHVlOi0xLG1heFZhbHVlOjF9LHtuYW1lOiJkZWNheUN1cnZlIixkZWZhdWx0VmFsdWU6MCxtaW5WYWx1ZTotMSxtYXhWYWx1ZToxfSx7bmFtZToicmVsZWFzZUN1cnZlIixkZWZhdWx0VmFsdWU6MCxtaW5WYWx1ZTotMSxtYXhWYWx1ZToxfSx7bmFtZToiZGVwdGgiLGRlZmF1bHRWYWx1ZToxfSx7bmFtZToibWluIixkZWZhdWx0VmFsdWU6LTFlOX0se25hbWU6Im1heCIsZGVmYXVsdFZhbHVlOjFlOX0se25hbWU6InJldHJpZ2dlciIsZGVmYXVsdFZhbHVlOjEsbWluVmFsdWU6MCxtYXhWYWx1ZToxfV19Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMudmFsPTAsdGhpcy5zZWdJZHg9MCx0aGlzLnN0YXRlPTAsdGhpcy5iZWdpblRpbWU9MCx0aGlzLmVuZFRpbWU9MCx0aGlzLmF0dGFja1N0YXJ0PTB9X3dhcnAodCxzLGU9OCl7aWYodD09PTB8fHQ9PT0xKXJldHVybiB0O2lmKHM+MCl7Y29uc3QgaT0xK2UqcztyZXR1cm4gMS1NYXRoLnBvdygxLXQsaSl9ZWxzZXtjb25zdCBpPTEtZSpzO3JldHVybiBNYXRoLnBvdyh0LGkpfX1fYWR2YW5jZSh0LHMsZSxpKXtpZihlPT09MHx8dD09PXMpdGhpcy52YWw9cztlbHNle2NvbnN0IG49TWF0aC5taW4oMSwoY3VycmVudFRpbWUtdGhpcy5iZWdpblRpbWUpL2UpLGE9dGhpcy5fd2FycChuLGkpO3RoaXMudmFsPXQrKHMtdCkqYX19cHJvY2Vzcyh0LHMsZSl7Y29uc3QgaT1lLmJlZ2luWzBdLG49ZS5lbmRbMF07aWYoY3VycmVudFRpbWU+PW4pcmV0dXJuITE7aWYoY3VycmVudFRpbWU8PWkpcmV0dXJuITA7Y29uc3QgYT1zWzBdWzBdLG89YihlLnJldHJpZ2dlciwwKT49LjU7aSE9PXRoaXMuYmVnaW5UaW1lJiYodGhpcy5zdGF0ZT09PTB8fG8pJiYodGhpcy5iZWdpblRpbWU9aSx0aGlzLnN0YXRlPTEsdGhpcy5lbmRUaW1lPWIoZS5lbmQsMCksdGhpcy5hdHRhY2tTdGFydD10aGlzLnZhbCk7Y29uc3QgYz10aGlzLmVuZFRpbWUtdGhpcy5iZWdpblRpbWU7Zm9yKGxldCBoPTA7aDxhLmxlbmd0aDtoKyspe2NvbnN0IGY9YihlLmF0dGFjayxoKSx1PWIoZS5kZWNheSxoKSxkPWIoZS5zdXN0YWluLGgpLGw9YihlLnJlbGVhc2UsaCkscD1iKGUuYXR0YWNrQ3VydmUsaCksbT1iKGUuZGVjYXlDdXJ2ZSxoKSxJPWIoZS5yZWxlYXNlQ3VydmUsaCksdz1iKGUuZGVwdGgsaCksdj1iKGUubWluLGgpLE09YihlLm1heCxoKSxQPVt7dGltZTpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFksc3RhcnQ6MCx0YXJnZXQ6MH0se3RpbWU6ZixzdGFydDp0aGlzLmF0dGFja1N0YXJ0LHRhcmdldDoxLGN1cnZlOnB9LHt0aW1lOmYrdSxzdGFydDoxLHRhcmdldDpkLGN1cnZlOm19LHt0aW1lOmMsc3RhcnQ6ZCx0YXJnZXQ6ZH0se3RpbWU6YytsLHN0YXJ0OmQsdGFyZ2V0OjAsY3VydmU6SX1dO2xldHt0aW1lOmcsc3RhcnQ6VCx0YXJnZXQ6QSxjdXJ2ZTpWfT1QW3RoaXMuc3RhdGVdO2Zvcih0aGlzLl9hZHZhbmNlKFQsQSxnLFYpO2N1cnJlbnRUaW1lLXRoaXMuYmVnaW5UaW1lPj1nOyl0aGlzLnN0YXRlPSh0aGlzLnN0YXRlKzEpJVAubGVuZ3RoLGc9UFt0aGlzLnN0YXRlXS50aW1lO2FbaF09Uyh0aGlzLnZhbCp3LHYsTSl9cmV0dXJuITB9fXJlZ2lzdGVyUHJvY2Vzc29yKCJlbnZlbG9wZS1wcm9jZXNzb3IiLE1lKTtjb25zdCB4PU9iamVjdC5mcmVlemUoe05PTkU6MCxBU1lNOjEsTUlSUk9SOjIsQkVORFA6MyxCRU5ETTo0LEJFTkRNUDo1LFNZTkM6NixRVUFOVDo3LEZPTEQ6OCxQV006OSxPUkJJVDoxMCxTUElOOjExLENIQU9TOjEyLFBSSU1FUzoxMyxCSU5BUlk6MTQsQlJPV05JQU46MTUsUkVDSVBST0NBTDoxNixXT1JNSE9MRToxNyxMT0dJU1RJQzoxOCxTSUdNT0lEOjE5LEZSQUNUQUw6MjAsRkxJUDoyMX0pO2Z1bmN0aW9uIHhlKHIpe3JldHVybiByPXIrMjEyNzkxMjIxNCsocjw8MTIpLHI9cl4zMzQ1MDcyNzAwXnI+Pj4xOSxyPXIrMzc0NzYxMzkzKyhyPDw1KSxyPXIrMzU1MDYzNTExNl5yPDw5LHI9cis0MjUxOTkzNzk3KyhyPDwzKSxyPXJeMzA0MjU5NDU2OV5yPj4+MTYscj4+PjB9Y29uc3QgS3Q9cj0+KHhlKHIpPj4+OCkvMTY3NzcyMTY7ZnVuY3Rpb24geWUocix0KXtsZXQgcz0wO2ZvcihsZXQgZT0wO2U8dDtlKyspcz1zPDwxfHImMSxyPj4+PTE7cmV0dXJuIHN9ZnVuY3Rpb24gUGUocil7Y29uc3QgdD1NYXRoLmZsb29yKHIpLHM9ci10LGU9S3QodCksaT1LdCh0KzEpO3JldHVybiBlKyhpLWUpKnN9ZnVuY3Rpb24gVGUocix0PTQpe2xldCBzPS41LGU9MCxpPTAsbj0xO2ZvcihsZXQgYT0wO2E8dDthKyspZSs9cypQZShyKm4pLGkrPXMscyo9LjUsbio9MjtyZXR1cm4gZS9pKjItMX1jb25zdCBWdD17fTtjbGFzcyBCZSBleHRlbmRzIEF1ZGlvV29ya2xldFByb2Nlc3NvcntzdGF0aWMgZ2V0IHBhcmFtZXRlckRlc2NyaXB0b3JzKCl7cmV0dXJuW3tuYW1lOiJiZWdpbiIsZGVmYXVsdFZhbHVlOi0xLG1pbjotMSxtYXg6TnVtYmVyLlBPU0lUSVZFX0lORklOSVRZfSx7bmFtZToiZW5kIixkZWZhdWx0VmFsdWU6LTEsbWluOi0xLG1heDpOdW1iZXIuUE9TSVRJVkVfSU5GSU5JVFl9LHtuYW1lOiJmcmVxdWVuY3kiLGRlZmF1bHRWYWx1ZTo0NDAsbWluOk51bWJlci5FUFNJTE9OfSx7bmFtZToiZGV0dW5lIixkZWZhdWx0VmFsdWU6MH0se25hbWU6ImZyZXFzcHJlYWQiLGRlZmF1bHRWYWx1ZTouMTgsbWluOjB9LHtuYW1lOiJwb3NpdGlvbiIsZGVmYXVsdFZhbHVlOjAsbWluOjAsbWF4OjF9LHtuYW1lOiJ3YXJwIixkZWZhdWx0VmFsdWU6MCxtaW46MCxtYXg6MX0se25hbWU6IndhcnBNb2RlIixkZWZhdWx0VmFsdWU6MH0se25hbWU6InZvaWNlcyIsZGVmYXVsdFZhbHVlOjEsbWluOjEsYXV0b21hdGlvblJhdGU6ImstcmF0ZSJ9LHtuYW1lOiJwYW5zcHJlYWQiLGRlZmF1bHRWYWx1ZTouNyxtaW46MCxtYXg6MX0se25hbWU6InBoYXNlcmFuZCIsZGVmYXVsdFZhbHVlOjAsbWluOjAsbWF4OjF9XX1jb25zdHJ1Y3Rvcih0KXtzdXBlcih0KSx0aGlzLnBvcnQub25tZXNzYWdlPXM9Pntjb25zdHt0eXBlOmUscGF5bG9hZDppfT1zLmRhdGF8fHt9O2U9PT0iaW5pdGlhbGl6ZSImJnRoaXMuaW5pdGlhbGl6ZShpKX0sdGhpcy5pbml0aWFsaXplKCl9aW5pdGlhbGl6ZSh0KXtpZih0aGlzLnRhYmxlPW51bGwsdGhpcy5mcmFtZUxlbj1udWxsLHRoaXMubnVtRnJhbWVzPW51bGwsdGhpcy5waGFzZT1bXSx0IT1udWxsJiZ0LmtleSl7Y29uc3Qgcz10LmtleTt0aGlzLmZyYW1lTGVuPXQuZnJhbWVMZW4sVnRbc118fChWdFtzXT10LmZyYW1lcyksdGhpcy50YWJsZT1WdFtzXSx0aGlzLm51bUZyYW1lcz10aGlzLnRhYmxlLmxlbmd0aH19X21pcnJvcih0KXtyZXR1cm4gMS1NYXRoLmFicygyKnQtMSl9X3RvQml0cyh0LHM9MixlPTEyKXtjb25zdCBpPWUrKHMtZSkqdDtyZXR1cm57YjppLG46c3QoTWF0aC5wb3coMixpKSl9fV93YXJwUGhhc2UodCxzLGUpe3N3aXRjaChlKXtjYXNlIHguTk9ORTpyZXR1cm4gdDtjYXNlIHguQVNZTTp7Y29uc3QgaT0uMDErLjk5KnM7cmV0dXJuIHQ8aT8uNSp0L2k6LjUrLjUqKHQtaSkvKDEtaSl9Y2FzZSB4Lk1JUlJPUjpyZXR1cm4gdGhpcy5fbWlycm9yKHRoaXMuX3dhcnBQaGFzZSh0LHMseC5BU1lNKSk7Y2FzZSB4LkJFTkRQOnJldHVybiBNYXRoLnBvdyh0LDErMypzKTtjYXNlIHguQkVORE06cmV0dXJuIE1hdGgucG93KHQsMS8oMSszKnMpKTtjYXNlIHguQkVORE1QOnJldHVybiBzPC41P3RoaXMuX3dhcnBQaGFzZSh0LDEtMipzLDMpOnRoaXMuX3dhcnBQaGFzZSh0LDIqcy0xLDIpO2Nhc2UgeC5TWU5DOntjb25zdCBpPU1hdGgucG93KDE2LHMqKjIpO3JldHVybiB0KmklMX1jYXNlIHguUVVBTlQ6e2NvbnN0e246aX09dGhpcy5fdG9CaXRzKHMpO3JldHVybiB0dCh0KmkpL2l9Y2FzZSB4LkZPTEQ6e2NvbnN0IG49MStNYXRoLm1heCgxLHN0KDcqcykpO3JldHVybiBNYXRoLmFicyhIdChuKnQpLS41KSoyfWNhc2UgeC5QV006e2NvbnN0IGk9UyguNSsuNDkqKDIqcy0xKSwwLDEpO3JldHVybiB0PGk/dC9pKi41Oi41Kyh0LWkpLygxLWkpKi41fWNhc2UgeC5PUkJJVDp7Y29uc3QgaT0uNSpzO3JldHVybiBRKHQraSpNYXRoLnNpbih6KjMqdCkpfWNhc2UgeC5TUElOOntjb25zdCBpPS41KnMse259PXRoaXMuX3RvQml0cyhzLDEsNik7cmV0dXJuIFEodCtpKk1hdGguc2luKHoqbip0KSl9Y2FzZSB4LkNIQU9TOntjb25zdCBuPSgzLjcrLjMqcykqdCooMS10KTtyZXR1cm4gUygoMS1zKSp0K3MqbiwwLDEpfWNhc2UgeC5QUklNRVM6e2NvbnN0IGk9YT0+e2lmKGE8MilyZXR1cm4hMTtpZihhJTI9PT0wKXJldHVybiBhPT09Mjtmb3IobGV0IG89MztvKioyPD1hO28rPTIpaWYoYSVvPT09MClyZXR1cm4hMTtyZXR1cm4hMH07bGV0e259PXRoaXMuX3RvQml0cyhzLDMpO2Zvcig7IWkobik7KW4rKztyZXR1cm4gdHQodCpuKS9ufWNhc2UgeC5CSU5BUlk6e2xldHtiOml9PXRoaXMuX3RvQml0cyhzLDMpO2k9c3QoaSk7Y29uc3Qgbj0xPDxpLGE9dHQodCpuKTtyZXR1cm4geWUoYSxpKS9ufWNhc2UgeC5CUk9XTklBTjp7Y29uc3QgaT0uMjUqcypUZSg2NCp0LDQpO3JldHVybiBRKHQraSl9Y2FzZSB4LlJFQ0lQUk9DQUw6e2NvbnN0IGk9Mis0KnMsbj10KmksYT10KygxLXQpKmksbz1hPjFlLTEyP24vYTowO3JldHVybiBTKG8sMCwxKX1jYXNlIHguV09STUhPTEU6e2NvbnN0IGk9UyguOCpzLDAsMSksbj0uNSooMS1pKSxhPS41KigxK2kpO3JldHVybiB0PG4/dC9uKi41OnQ+YT8uNSooMSsodC1hKS8oMS1hKSk6LjV9Y2FzZSB4LkxPR0lTVElDOntsZXQgaT10O2NvbnN0IG49My42Ky40KnMsYT0xK3N0KDIqcyk7Zm9yKGxldCBvPTA7bzxhO28rKylpPW4qaSooMS1pKTtyZXR1cm4gUyhpLDAsMSl9Y2FzZSB4LlNJR01PSUQ6e2NvbnN0IGk9MSsxMCpzLG49dC0uNSxhPTEvKDErTWF0aC5leHAoLWkqbikpLG89MS8oMStNYXRoLmV4cCguNSppKSksYz0xLygxK01hdGguZXhwKC0uNSppKSk7cmV0dXJuKGEtbykvKGMtbyl9Y2FzZSB4LkZSQUNUQUw6e2NvbnN0IGk9LjUqTWF0aC5zaW4oeip0KSpzO3JldHVybiBRKHQraSl9Y2FzZSB4LkZMSVA6cmV0dXJuIHQ7ZGVmYXVsdDpyZXR1cm4gdH19X3NhbXBsZUZyYW1lKHQscyl7Y29uc3QgZT10Lmxlbmd0aCxpPXMqZTtsZXQgbj1pfDA7bj49ZSYmKG49MCk7Y29uc3QgYT1pLW4sbz10W25dO2xldCBjPW4rMTtjPj1lJiYoYz0wKTtjb25zdCBoPXRbY107cmV0dXJuIG8rKGgtbykqYX1wcm9jZXNzKHQscyxlKXtjb25zdCBpPWUuYmVnaW5bMF0sbj1lLmVuZFswXSxhPWk+PTAsbz1uPj0wLGM9byYmY3VycmVudFRpbWU+PW4rLjUsaD1vJiZjdXJyZW50VGltZT49bixmPWN1cnJlbnRUaW1lPD1pO2lmKGMpcmV0dXJuITE7aWYoaHx8Znx8IWEpcmV0dXJuITA7Y29uc3QgdT1zWzBdWzBdLGQ9c1swXVsxXXx8c1swXVswXTtpZighdGhpcy50YWJsZSlyZXR1cm4gdS5maWxsKDApLGQhPT11JiZkLnNldCh1KSwhMDtjb25zdCBsPWUudm9pY2VzWzBdO2ZvcihsZXQgcD0wO3A8dS5sZW5ndGg7cCsrKXtjb25zdCBtPWIoZS5kZXR1bmUscCksST1iKGUuZnJlcXNwcmVhZCxwKSx2PVMoYihlLnBvc2l0aW9uLHApLDAsMSkqKHRoaXMubnVtRnJhbWVzLTEpLE09dnwwLFA9di1NLGc9UyhiKGUud2FycCxwKSwwLDEpLFQ9YihlLndhcnBNb2RlLHApLEE9UyhiKGUucGhhc2VyYW5kLHApLDAsMSksVj1sPjE/UyhiKGUucGFuc3ByZWFkLHApLDAsMSk6MCxPPU1hdGguc3FydCguNS0uNSpWKSxOPU1hdGguc3FydCguNSsuNSpWKTtsZXQgQz1iKGUuZnJlcXVlbmN5LHApO0M9ZXQoQyxtLzEwMCk7Y29uc3QgRj0xL01hdGguc3FydChsKSxxPVV0KGwsSSk7Zm9yKGxldCBCPTA7QjxsO0IrKyl7Y29uc3QgTD0oQiYxKT09MTtsZXQgRT1PLEg9TjtMJiYoRT1OLEg9Tyk7Y29uc3QgJD1ldChDLHEoQikpKkc7dGhpcy5waGFzZVtCXT10aGlzLnBoYXNlW0JdPz9NYXRoLnJhbmRvbSgpKkE7Y29uc3QgVT10aGlzLl93YXJwUGhhc2UodGhpcy5waGFzZVtCXSxnLFQpLEs9dGhpcy5fc2FtcGxlRnJhbWUodGhpcy50YWJsZVtNXSxVKSxaPXRoaXMuX3NhbXBsZUZyYW1lKHRoaXMudGFibGVbTWF0aC5taW4odGhpcy5udW1GcmFtZXMtMSxNKzEpXSxVKTtsZXQgaz11dChLLFosUCk7VD09PXguRkxJUCYmdGhpcy5waGFzZVtCXTxnJiYoaz0tayksdVtwXSs9aypFKkYsZFtwXSs9aypIKkYsdGhpcy5waGFzZVtCXT1RKHRoaXMucGhhc2VbQl0rJCl9fXJldHVybiEwfX1yZWdpc3RlclByb2Nlc3Nvcigid2F2ZXRhYmxlLW9zY2lsbGF0b3ItcHJvY2Vzc29yIixCZSk7Y2xhc3MgVmUgZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7c3RhdGljIGdldCBwYXJhbWV0ZXJEZXNjcmlwdG9ycygpe3JldHVybltdfWNvbnN0cnVjdG9yKHQpe3N1cGVyKCksdGhpcy5nYWluQ29lZmY9eHQoLjIpLHRoaXMuYXZnR2Fpbj0xO2xldHthdHRhY2tUaW1lOnM9LjAwMyxzdXN0YWluVGltZTplPS4wOCxhdHRhY2s6aT0wLHN1c3RhaW46bj0wLHNlbnNpdGl2aXR5OmE9LjEsbWl4Om89MSxiZWdpbjpjPTAsZW5kOmg9MH09dC5wcm9jZXNzb3JPcHRpb25zO3M9UyhzLDVlLTQsLjA1KSxlPVMoZSwuMDEsLjUpLHRoaXMuYXR0YWNrQ29lZmY9eHQocyksdGhpcy5zdXN0YWluQ29lZmY9eHQoZSksdGhpcy5hdHRhY2tBbXQ9UyhpLC0xLDEpLHRoaXMuc3VzdGFpbkFtdD1TKG4sLTEsMSksdGhpcy5zY2FsaW5nPS41KzUqUyhhLDAsMSksdGhpcy5taXg9UyhvLDAsMSksdGhpcy5iZWdpbj1jLHRoaXMuZW5kPWgsdGhpcy5hdHRhY2tFbnY9bmV3IEZsb2F0MzJBcnJheSgyKSx0aGlzLnN1c3RhaW5FbnY9bmV3IEZsb2F0MzJBcnJheSgyKX1wcm9jZXNzKHQscyxlKXtjb25zdCBpPXRbMF0sbj1zWzBdO2lmKGN1cnJlbnRUaW1lPj10aGlzLmVuZClyZXR1cm4hMTtpZihjdXJyZW50VGltZTw9dGhpcy5iZWdpbilyZXR1cm4hMDtjb25zdCBhPWkubGVuZ3RoO2E+dGhpcy5hdHRhY2tFbnYubGVuZ3RoJiYodGhpcy5hdHRhY2tFbnY9bmV3IEZsb2F0MzJBcnJheShhKSx0aGlzLnN1c3RhaW5FbnY9bmV3IEZsb2F0MzJBcnJheShhKSk7bGV0IG89dGhpcy5hdmdHYWluO2ZvcihsZXQgYz0wO2M8YTtjKyspe2xldCBoPXRoaXMuYXR0YWNrRW52W2NdLGY9dGhpcy5zdXN0YWluRW52W2NdO2ZvcihsZXQgdT0wO3U8WTt1Kyspe2NvbnN0IGQ9aVtjXVt1XSxsPU1hdGguYWJzKGQpO2g9dXQoaCxsLHRoaXMuYXR0YWNrQ29lZmYpLGY9dXQoZixsLHRoaXMuc3VzdGFpbkNvZWZmKTtjb25zdCBwPVModGhpcy5zY2FsaW5nKihoLWYpLyhmKzFlLTYpLC0xLjUsMS41KSxtPXA+MD9wOjAsST1wPDA/LXA6MCx3PWp0KHRoaXMuYXR0YWNrQW10Km0qMTgpLHY9anQodGhpcy5zdXN0YWluQW10KkkqMzYpLE09Uyh3KnYsMCw4KTtvPXV0KG8sTSx0aGlzLmdhaW5Db2VmZik7Y29uc3QgUD1vPi4wMDE/MS9vOjEsZz1kKk0qUDtsZXQgVD11dChkLGcsdGhpcy5taXgpO1QvPTErTWF0aC5hYnMoVCksbltjXVt1XT1UfXRoaXMuYXR0YWNrRW52W2NdPWgsdGhpcy5zdXN0YWluRW52W2NdPWZ9cmV0dXJuIHRoaXMuYXZnR2Fpbj1vLCEwfX1yZWdpc3RlclByb2Nlc3NvcigidHJhbnNpZW50LXByb2Nlc3NvciIsVmUpO2NsYXNzIEFlIGV4dGVuZHMgQXVkaW9Xb3JrbGV0UHJvY2Vzc29ye2NvbnN0cnVjdG9yKCl7c3VwZXIoKSx0aGlzLnBsYXlQb3M9MDtjb25zdCB0PTE2O3RoaXMub3V0cHV0cz1uZXcgQXJyYXkodCkuZmlsbCgwKSx0aGlzLnNvdXJjZXM9bmV3IEFycmF5KHQpLmZpbGwoMCksdGhpcy5nYXRlRW5kZWQ9ITEsdGhpcy5zdGFydGVkPSExLHRoaXMucG9ydC5vbm1lc3NhZ2U9cz0+e3ZhciBoLGY7bGV0e3NyYzplLHNjaGVtYTp7dWdlbnM6aSxyZWdpc3RlcnM6bn0sc3RhcnQ6YSxnYXRlRW5kOm8sZW5kOmN9PXMuZGF0YTt0aGlzLnN0YXJ0PWEsdGhpcy5nYXRlRW5kPW8sdGhpcy5lbmQ9Yyx0aGlzLnJlZ2lzdGVycz1uZXcgQXJyYXkobikuZmlsbCgwKSx0aGlzLnNyYz1gby5maWxsKDApOyAvLyByZXNldCBvdXRwdXRzCiR7ZX1gLHRoaXMubm9kZXM9W107Zm9yKGxldCB1PTA7dTxpLmxlbmd0aDt1Kyspe2NvbnN0IGQ9aVt1XSxsPW5lLmdldChkLnR5cGUpLHA9bmV3IGwodSxkLHNhbXBsZVJhdGUpO3AudHlwZT09PSJjYyImJigoZj0oaD1kLmlucHV0cyk9PW51bGw/dm9pZCAwOmhbMF0pIT1udWxsJiZmLmluY2x1ZGVzKCJzdHJ1ZGVsLWdhdGUiKSkmJihwLnNldFZhbHVlKDEpLHRoaXMuZ2F0ZU5vZGU9cCksdGhpcy5ub2Rlc1t1XT1wfXRoaXMuZ2VuU2FtcGxlPW5ldyBGdW5jdGlvbigidGltZSIsIm5vZGVzIiwiaW5wdXQiLCJyIiwibyIsInMiLHRoaXMuc3JjKX19cHJvY2Vzcyh0LHMpe3ZhciBvLGM7Y29uc3QgZT0obz10WzBdKT09bnVsbD92b2lkIDA6b1swXTtpZihjdXJyZW50VGltZT49dGhpcy5lbmQpcmV0dXJuITE7aWYodGhpcy5nZW5TYW1wbGU9PT12b2lkIDB8fGN1cnJlbnRUaW1lPHRoaXMuc3RhcnQpcmV0dXJuITA7dGhpcy5zdGFydGVkPSEwLCF0aGlzLmdhdGVFbmRlZCYmY3VycmVudFRpbWU+dGhpcy5nYXRlRW5kJiYoKGM9dGhpcy5nYXRlTm9kZSk9PW51bGx8fGMuc2V0VmFsdWUoMCksdGhpcy5nYXRlRW5kZWQ9ITApO2NvbnN0IGk9c1swXSxuPWlbMF0sYT1pWzFdO2ZvcihsZXQgaD0wO2g8WTtoKyspe3RoaXMuZ2VuU2FtcGxlKHRoaXMucGxheVBvcyx0aGlzLm5vZGVzLGU/ZVtoXTowLHRoaXMucmVnaXN0ZXJzLHRoaXMub3V0cHV0cyx0aGlzLnNvdXJjZXMpO2NvbnN0IGY9dGhpcy5vdXRwdXRzWzBdLHU9dGhpcy5vdXRwdXRzWzFdO2E/KG5baF09ZixhW2hdPXUpOm5baF09LjUqKGYrdSksdGhpcy5wbGF5UG9zKz0xL3NhbXBsZVJhdGV9cmV0dXJuITB9fXJldHVybiByZWdpc3RlclByb2Nlc3NvcigiZ2VuZXJpYy1wcm9jZXNzb3IiLEFlKSxSLldhcnBNb2RlPXgsT2JqZWN0LmRlZmluZVByb3BlcnR5KFIsU3ltYm9sLnRvU3RyaW5nVGFnLHt2YWx1ZToiTW9kdWxlIn0pLFJ9KHt9KTsK";
  var jn2 = {
    stretch: { node: "stretch", param: "pitchFactor" },
    gain: { node: "gain", param: "gain" },
    postgain: { node: "post", param: "gain" },
    pan: { node: "pan", param: "pan" },
    tremolo: { node: "tremolo", param: "frequency" },
    tremolosync: { node: "tremolo", param: "frequency" },
    tremolodepth: { node: "tremolo_gain", param: "gain" },
    tremoloskew: { node: "tremolo", param: "skew" },
    tremolophase: { node: "tremolo", param: "phase" },
    tremoloshape: { node: "tremolo", param: "shape" },
    // MODULATORS
    lfo: { node: "lfo", param: "frequency" },
    lfo_rate: { node: "lfo", param: "frequency" },
    lfo_sync: { node: "lfo", param: "frequency" },
    lfo_depth: { node: "lfo", param: "depth" },
    lfo_depthabs: { node: "lfo", param: "depth" },
    lfo_skew: { node: "lfo", param: "skew" },
    lfo_curve: { node: "lfo", param: "curve" },
    lfo_dcoffset: { node: "lfo", param: "dcoffset" },
    env: { node: "env", param: "depth" },
    env_attack: { node: "env", param: "attack" },
    env_decay: { node: "env", param: "decay" },
    env_sustain: { node: "env", param: "sustain" },
    env_release: { node: "env", param: "release" },
    bmod: { node: "bmod", param: "depth" },
    bmod_depth: { node: "bmod", param: "depth" },
    bmod_depthabs: { node: "bmod", param: "depth" },
    // LPF
    cutoff: { node: "lpf", param: "frequency" },
    resonance: { node: "lpf", param: "Q" },
    lprate: { node: "lpf_lfo", param: "rate" },
    lpsync: { node: "lpf_lfo", param: "sync" },
    lpdepth: { node: "lpf_lfo", param: "depth" },
    lpdepthfrequency: { node: "lpf_lfo", param: "depth" },
    lpshape: { node: "lpf_lfo", param: "shape" },
    lpdc: { node: "lpf_lfo", param: "dcoffset" },
    lpskew: { node: "lpf_lfo", param: "skew" },
    // HPF
    hcutoff: { node: "hpf", param: "frequency" },
    hresonance: { node: "hpf", param: "Q" },
    hprate: { node: "hpf_lfo", param: "rate" },
    hpsync: { node: "hpf_lfo", param: "sync" },
    hpdepth: { node: "hpf_lfo", param: "depth" },
    hpdepthfrequency: { node: "hpf_lfo", param: "depth" },
    hpshape: { node: "hpf_lfo", param: "shape" },
    hpdc: { node: "hpf_lfo", param: "dcoffset" },
    hpskew: { node: "hpf_lfo", param: "skew" },
    // BPF
    bandf: { node: "bpf", param: "frequency" },
    bandq: { node: "bpf", param: "Q" },
    bprate: { node: "bpf_lfo", param: "rate" },
    bpsync: { node: "bpf_lfo", param: "sync" },
    bpdepth: { node: "bpf_lfo", param: "depth" },
    bpdepthfrequency: { node: "bpf_lfo", param: "depth" },
    bpshape: { node: "bpf_lfo", param: "shape" },
    bpdc: { node: "bpf_lfo", param: "dcoffset" },
    bpskew: { node: "bpf_lfo", param: "skew" },
    vowel: { node: "vowel", param: "frequency" },
    // DISTORTION
    coarse: { node: "coarse", param: "coarse" },
    crush: { node: "crush", param: "crush" },
    shape: { node: "shape", param: "shape" },
    shapevol: { node: "shape", param: "postgain" },
    distort: { node: "distort", param: "distort" },
    distortvol: { node: "distort", param: "postgain" },
    distorttype: { node: "distort", param: "distort" },
    // COMPRESSOR
    compressor: { node: "compressor", param: "threshold" },
    compressorRatio: { node: "compressor", param: "ratio" },
    compressorKnee: { node: "compressor", param: "knee" },
    compressorAttack: { node: "compressor", param: "attack" },
    compressorRelease: { node: "compressor", param: "release" },
    // PHASER
    phaserrate: { node: "phaser_lfo", param: "frequency" },
    phasersweep: { node: "phaser_lfo", param: "depth" },
    phasercenter: { node: "phaser", param: "frequency" },
    phaserdepth: { node: "phaser", param: "Q" },
    // ORBIT EFFECTS
    delay: { node: "delay_mix", param: "gain" },
    delaytime: { node: "delay", param: "delayTime" },
    delayfeedback: { node: "delay", param: "feedback" },
    delaysync: { node: "delay", param: "delayTime" },
    dry: { node: "dry", param: "gain" },
    room: { node: "room_mix", param: "gain" },
    djf: { node: "djf", param: "value" },
    busgain: { node: "bus", param: "gain" },
    // SYNTHS
    s: { node: "source", param: "frequency" },
    detune: { node: "source", param: "freqspread" },
    wt: { node: "source", param: "position" },
    warp: { node: "source", param: "warp" },
    freq: { node: "source", param: "frequency" },
    note: { node: "source", param: "frequency" },
    wtdc: { node: "wt_lfo", param: "dc" },
    wtskew: { node: "wt_lfo", param: "skew" },
    wtrate: { node: "wt_lfo", param: "frequency" },
    wtsync: { node: "wt_lfo", param: "frequency" },
    wtdepth: { node: "wt_lfo", param: "depth" },
    warpdc: { node: "warp_lfo", param: "dc" },
    warpskew: { node: "warp_lfo", param: "skew" },
    warprate: { node: "warp_lfo", param: "frequency" },
    warpsync: { node: "warp_lfo", param: "frequency" },
    warpdepth: { node: "warp_lfo", param: "depth" },
    fmi: { node: "fm_1_gain", param: "gain" },
    fmi2: { node: "fm_2_gain", param: "gain" },
    fmi3: { node: "fm_3_gain", param: "gain" },
    fmi4: { node: "fm_4_gain", param: "gain" },
    fmi5: { node: "fm_5_gain", param: "gain" },
    fmi6: { node: "fm_6_gain", param: "gain" },
    fmi7: { node: "fm_7_gain", param: "gain" },
    fmi8: { node: "fm_8_gain", param: "gain" },
    fmh: { node: "fm_1", param: "frequency" },
    fmh2: { node: "fm_2", param: "frequency" },
    fmh3: { node: "fm_3", param: "frequency" },
    fmh4: { node: "fm_4", param: "frequency" },
    fmh5: { node: "fm_5", param: "frequency" },
    fmh6: { node: "fm_6", param: "frequency" },
    fmh7: { node: "fm_7", param: "frequency" },
    fmh8: { node: "fm_8", param: "frequency" },
    pw: { node: "source", param: "pulsewidth" },
    pwrate: { node: "pw_lfo", param: "frequency" },
    pwsweep: { node: "pw_lfo", param: "depth" },
    vib: { node: "vib", param: "frequency" },
    vibmod: { node: "vib_gain", param: "gain" },
    byteBeatStartTime: { node: "source", param: "byteBeatStartTime" },
    spread: { node: "source", param: "panspread" },
    transient: { node: "transient", param: "attack" }
  };
  function Bn2() {
    return jn2;
  }
  var Qn2 = (e, t) => {
    if (e?.parameters) {
      const o = e.parameters.get(t);
      if (o instanceof AudioParam)
        return o;
    }
    let n2 = e?.[t];
    if (n2 === void 0 && t === "frequency" && (n2 = e?.detune ?? e?.playbackRate), n2 instanceof AudioParam)
      return n2;
  };
  var St2 = Bn2();
  var vn2 = (e, t) => {
    const n2 = e.split("_")[0];
    return St2[`${n2}_${t}`] ?? St2[n2];
  };
  var Gt2 = (e, t) => e === "frequency" && t >= 30 ? { min: 20 - t, max: 24e3 - t } : { min: void 0, max: void 0 };
  var En2 = (e, t, n2) => {
    const o = z2(), a2 = new Float32Array(256);
    for (let d2 = 0; d2 < a2.length; d2++) {
      const l2 = d2 / (a2.length - 1) * 2 - 1;
      a2[d2] = se2(l2 * n2, t, n2);
    }
    const c3 = new WaveShaperNode(o, { curve: a2 }), s2 = T2(1 / n2);
    return e.connect(s2).connect(c3), { modulator: e, toCleanup: [c3, s2] };
  };
  var Xt3 = (e, t, n2) => {
    const o = vn2(e, n2);
    if (!o)
      return ct3(
        new Error(`Could not find control data for target '${e}'. It may not be modulatable.`),
        "superdough"
      ), { targetParams: [], paramName: e };
    const a2 = o.param, c3 = t[o.node] ? o.node : e, s2 = t[c3];
    if (!s2) {
      const l2 = Object.keys(t);
      return ct3(
        new Error(`Could not connect to target '${c3}' \u2014 it does not exist. Available targets: ${l2.join(", ")}`),
        "superdough"
      ), { targetParams: [], paramName: a2 };
    }
    const d2 = [];
    return s2.forEach((l2) => {
      const i = Qn2(l2, a2);
      d2.push(i);
    }), { targetParams: d2, paramName: a2 };
  };
  var On2 = (e, t, n2) => {
    const {
      rate: o = 1,
      sync: a2,
      cps: c3,
      cycle: s2,
      control: d2 = "lfo",
      subControl: l2,
      fxi: i = "main",
      depth: p2 = 1,
      depthabs: r,
      ...h
    } = t, { targetParams: u3, paramName: m3 } = Xt3(d2, n2[i], l2);
    if (!u3.length) return;
    let G4 = u3[0].value;
    G4 = G4 === 0 ? 1 : G4;
    const { min: b2, max: f4 } = Gt2(m3, G4), y3 = r ?? p2 * G4, M2 = {
      ...h,
      frequency: a2 !== void 0 ? a2 * c3 : o,
      time: s2 / c3,
      depth: y3,
      min: b2,
      max: f4
    }, Z5 = Fe2(z2(), M2);
    return n2.main[`lfo_${e}`] = [Z5], u3.forEach((W6) => Z5.connect(W6)), Z5;
  };
  var Dn2 = (e, t, n2) => {
    const { control: o, subControl: a2, acurve: c3, dcurve: s2, rcurve: d2, depth: l2 = 1, depthabs: i, fxi: p2 = "main", ...r } = t, { targetParams: h, paramName: u3 } = Xt3(o, n2[p2], a2);
    if (!h.length) return;
    let m3 = h[0].value;
    m3 = m3 === 0 ? 1 : m3;
    const { min: G4, max: b2 } = Gt2(u3, m3), f4 = i ?? l2 * m3, y3 = Vn2(z2(), {
      ...r,
      depth: f4,
      min: G4,
      max: b2,
      attackCurve: c3,
      decayCurve: s2,
      releaseCurve: d2
    });
    return n2.main[`env_${e}`] = [y3], h.forEach((M2) => y3.connect(M2)), y3;
  };
  var An2 = (e, t, n2) => {
    const o = z2(), { control: a2, subControl: c3, depth: s2 = 1, depthabs: d2, fxi: l2 = "main" } = e, { targetParams: i, paramName: p2 } = Xt3(a2, t[l2], c3);
    if (!i.length) return { toCleanup: [] };
    const r = n2.getBus(e.bus), h = new ConstantSourceNode(o, { offset: e.dc ?? 0 });
    h.start(e.begin);
    const u3 = h.connect(T2(1));
    r.connect(u3);
    let m3 = i[0].value;
    m3 = m3 === 0 ? 1 : m3;
    const { min: G4, max: b2 } = Gt2(p2, m3), f4 = d2 ?? s2 * m3, y3 = T2(Math.sign(f4) * Math.abs(f4) / 0.3), M2 = u3.connect(y3), Z5 = [];
    let W6 = M2;
    if (G4 !== void 0 && b2 !== void 0) {
      const S5 = En2(M2, G4, b2);
      W6 = S5.modulator, Z5.push(...S5.toCleanup);
    }
    return pe3(
      o,
      () => {
        i.forEach((S5) => W6.connect(S5));
      },
      0,
      e.begin
    ), Z5.push(h, u3, y3), { modulator: W6, toCleanup: Z5 };
  };
  var yt3 = {};
  var tt2 = {};
  var Eo2 = (e) => yt3[e];
  function qn2(e, t) {
    var n2 = 1024;
    if (e < n2) return e + " B";
    var o = ["KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"], a2 = -1;
    do
      e /= n2, ++a2;
    while (e >= n2);
    return e.toFixed(1) + " " + o[a2];
  }
  function _n2(e, t) {
    const { speed: n2 = 1 } = e, { transpose: o, url: a2, index: c3, midi: s2, label: d2 } = It3(e, t);
    let l2 = Math.abs(n2) * Math.pow(2, o / 12);
    return { transpose: o, url: a2, index: c3, midi: s2, label: d2, playbackRate: l2 };
  }
  var $n2 = async (e, t, n2) => {
    let { url: o, label: a2, playbackRate: c3 } = _n2(e, t);
    n2 && (o = await n2(o));
    const s2 = z2(), d2 = await dt3(o, s2, a2);
    return e.unit === "c" && (c3 = c3 * d2.duration), { buffer: d2, playbackRate: c3 };
  };
  var eo2 = async (e, t, n2) => {
    let { buffer: o, playbackRate: a2 } = await $n2(e, t, n2);
    e.speed < 0 && (o = to2(o));
    const s2 = z2().createBufferSource();
    s2.buffer = o, s2.playbackRate.value = a2;
    const { loopBegin: d2 = 0, loopEnd: l2 = 1, begin: i = 0, end: p2 = 1 } = e, r = s2.buffer.duration, h = i * r;
    e.loop && (s2.loop = true, s2.loopStart = d2 * r, s2.loopEnd = l2 * r);
    const m3 = r / s2.playbackRate.value, G4 = (p2 - i) * m3;
    return { bufferSource: s2, offset: h, bufferDuration: r, playbackDuration: m3, sliceDuration: G4 };
  };
  var dt3 = (e, t, n2, o = 0) => {
    const a2 = n2 ? `sound "${n2}:${o}"` : "sample";
    if (e = e.replace("#", "%23"), !tt2[e]) {
      j3(`[sampler] load ${a2}..`, "load-sample", { url: e });
      const c3 = Date.now();
      tt2[e] = fetch(e).then((s2) => s2.arrayBuffer()).then(async (s2) => {
        const d2 = Date.now() - c3, l2 = qn2(s2.byteLength);
        j3(`[sampler] load ${a2}... done! loaded ${l2} in ${d2}ms`, "loaded-sample", { url: e });
        const i = await t.decodeAudioData(s2);
        return yt3[e] = i, i;
      });
    }
    return tt2[e];
  };
  function to2(e) {
    const t = z2(), n2 = t.createBuffer(e.numberOfChannels, e.length, t.sampleRate);
    for (let o = 0; o < e.numberOfChannels; o++)
      n2.copyToChannel(e.getChannelData(o).slice().reverse(), o, o);
    return n2;
  }
  var Oo2 = (e) => yt3[e];
  function Ot3(e) {
    if (e.startsWith("bubo:")) {
      const [t, n2] = e.split(":");
      e = `github:Bubobubobubobubo/dough-${n2}`;
    }
    return e;
  }
  function Dt2(e, t = "") {
    if (!e.startsWith("github:"))
      throw new Error('expected "github:" at the start of pseudoUrl');
    let n2 = e.slice(7);
    n2 = n2.endsWith("/") ? n2.slice(0, -1) : n2;
    let o = n2.split("/"), a2 = o[0], c3 = o.length >= 2 ? o[1] : "samples", s2 = o.length >= 3 ? o[2] : "main", d2 = o.slice(3);
    return d2.push(t || ""), d2 = d2.join("/"), `https://raw.githubusercontent.com/${a2}/${c3}/${s2}/${d2}`;
  }
  var no2 = (e, t, n2 = e._base || "") => Object.entries(e).forEach(([o, a2]) => {
    if (typeof a2 == "string" && (a2 = [a2]), typeof a2 != "object")
      throw new Error("wrong sample map format for " + o);
    n2 = a2._base || n2, n2 = Ot3(n2), n2.startsWith("github:") && (n2 = Dt2(n2, ""));
    const c3 = (s2) => n2 + s2;
    Array.isArray(a2) ? a2 = a2.map(c3) : a2 = Object.fromEntries(
      Object.entries(a2).map(([s2, d2]) => [s2, (typeof d2 == "string" ? [d2] : d2).map(c3)])
    ), t(o, a2);
  });
  var At2 = {};
  function Do2(e, t) {
    At2[e] = t;
  }
  function oo2(e) {
    const t = Object.entries(At2).find(([n2]) => e.startsWith(n2));
    if (t)
      return t[1];
  }
  async function co2(e) {
    const t = oo2(e);
    if (t)
      return t(e);
    if (e = Ot3(e), e.startsWith("github:") && (e = Dt2(e, "strudel.json")), e.startsWith("local:") && (e = "http://localhost:5432"), e.startsWith("shabda:")) {
      let [a2, c3] = e.split("shabda:");
      e = `https://shabda.ndre.gr/${c3}.json?strudel=1`;
    }
    if (e.startsWith("shabda/speech")) {
      let [a2, c3] = e.split("shabda/speech");
      c3 = c3.startsWith("/") ? c3.substring(1) : c3;
      let [s2, d2] = c3.split(":"), l2 = "f", i = "en-GB";
      s2 && ([i, l2] = s2.split("/")), e = `https://shabda.ndre.gr/speech/${d2}.json?gender=${l2}&language=${i}&strudel=1'`;
    }
    if (typeof fetch != "function")
      return;
    const n2 = Jt3(e);
    if (typeof fetch > "u")
      return;
    const o = await fetch(e).then((a2) => a2.json()).catch((a2) => {
      throw console.error(a2), new Error(`error loading "${e}"`);
    });
    return [o, o._base || n2];
  }
  var ao2 = async (e, t = e._base || "", n2 = {}) => {
    if (typeof e == "string") {
      const [c3, s2] = await co2(e);
      return ao2(c3, t || s2, n2);
    }
    const { prebake: o, tag: a2 } = n2;
    no2(
      e,
      (c3, s2) => {
        io2(c3, s2, { baseUrl: t, prebake: o, tag: a2 });
      },
      t
    );
  };
  var Kt3 = [];
  async function so2(e, t, n2, o, a2) {
    let {
      s: c3,
      nudge: s2 = 0,
      // TODO: is this in seconds?
      cut: d2,
      loop: l2,
      clip: i = void 0,
      // if set, samples will be cut off when the hap ends
      n: p2 = 0,
      speed: r = 1,
      // sample playback speed
      duration: h
    } = t;
    if (r === 0)
      return;
    const u3 = z2();
    let [m3, G4, b2, f4] = $3([t.attack, t.decay, t.sustain, t.release]);
    const { bufferSource: y3, sliceDuration: M2, offset: Z5 } = await eo2(t, o, a2);
    if (!y3) {
      j3(`[sampler] could not load "${c3}:${p2}"`, "error");
      return;
    }
    if (u3.currentTime > e) {
      j3(`[sampler] loading sound "${c3}:${p2}" took too long`, "highlight"), Y3(y3);
      return;
    }
    const W6 = Te3(y3.detune, t, e), S5 = e + s2;
    y3.start(S5, Z5);
    const Q4 = u3.createGain(), F4 = y3.connect(Q4);
    i == null && l2 == null && t.release == null && (h = M2);
    let N5 = e + h;
    _2(F4.gain, m3, G4, b2, f4, 0, 1, e, N5, "linear"), He2(y3.detune, t, e, N5);
    const g3 = u3.createGain();
    F4.connect(g3), ue3(y3, function() {
      Y3(y3), W6?.stop(), Y3(F4), Y3(g3), n2();
    });
    let C6 = N5 + f4 + 0.01;
    y3.stop(C6);
    const K4 = (k6) => {
      y3.stop(k6);
    }, I3 = { node: g3, nodes: { source: [y3], ...W6?.nodes }, stop: K4 };
    if (d2 !== void 0) {
      const k6 = Kt3[d2];
      k6 && (k6.node.gain.setValueAtTime(1, S5), k6.node.gain.linearRampToValueAtTime(0, S5 + 0.01)), Kt3[d2] = I3;
    }
    return I3;
  }
  function lo2(e, t, n2) {
    ce3(e, (o, a2, c3) => so2(o, a2, c3, t), {
      type: "sample",
      samples: t,
      ...n2
    });
  }
  function io2(e, t, n2) {
    e.startsWith("wt_") ? _t3(e, t, n2) : lo2(e, t, n2);
  }
  var fe3 = (e, t) => e !== void 0 && e !== t;
  var lt3 = (e) => new GainNode(e, { gain: 1, channelCount: 2, channelCountMode: "explicit" });
  var ro2 = class {
    constructor(t) {
      __publicField(this, "reverbNode");
      __publicField(this, "delayNode");
      __publicField(this, "output");
      __publicField(this, "summingNode");
      __publicField(this, "djfNode");
      __publicField(this, "audioContext");
      this.audioContext = t, this.output = lt3(t), this.summingNode = lt3(t), this.summingNode.connect(this.output);
    }
    disconnect() {
      this.output.disconnect(), this.summingNode.disconnect(), this.delayNode?.disconnect(), this.reverbNode?.disconnect();
    }
    getDjf(t, n2 = 0) {
      return this.djfNode == null && (this.djfNode = q3(this.audioContext, "djf-processor", { value: t }), this.summingNode.disconnect(), this.summingNode.connect(this.djfNode), this.djfNode.connect(this.output)), this.djfNode.parameters.get("value").setValueAtTime(t, n2), this.djfNode;
    }
    getDelay(t = 0, n2 = 0.5, o) {
      return n2 = se2(n2, 0, 0.98), this.delayNode == null && (this.delayNode = this.audioContext.createFeedbackDelay(1, t, n2), this.delayNode.connect(this.summingNode), this.delayNode.start?.(o)), this.delayNode.delayTime.value !== t && this.delayNode.delayTime.setValueAtTime(t, o), this.delayNode.feedback.value !== n2 && this.delayNode.feedback.setValueAtTime(n2, o), this.delayNode;
    }
    getReverb(t, n2, o, a2, c3, s2, d2) {
      return this.reverbNode == null && (this.reverbNode = this.audioContext.createReverb(t, n2, o, a2, c3, s2, d2), this.reverbNode.connect(this.summingNode)), (fe3(t, this.reverbNode.duration) || fe3(n2, this.reverbNode.fade) || fe3(o, this.reverbNode.lp) || fe3(a2, this.reverbNode.dim) || fe3(s2, this.reverbNode.irspeed) || fe3(d2, this.reverbNode.irbegin) || this.reverbNode.ir !== c3) && this.reverbNode.generate(t, n2, o, a2, c3, s2, d2), this.reverbNode;
    }
    sendReverb(t, n2) {
      return Ue3(t, this.reverbNode, n2);
    }
    sendDelay(t, n2) {
      return Ue3(t, this.delayNode, n2);
    }
    duck(t, n2 = 0, o = 0.1, a2 = 1) {
      const c3 = n2, s2 = Math.max(o, 2e-3), d2 = this.output.gain;
      pe3(
        this.audioContext,
        () => {
          const l2 = this.audioContext.currentTime, i = d2.value;
          d2.cancelScheduledValues(l2), d2.setValueAtTime(i, l2);
          const p2 = Math.max(t, l2), r = se2(1 - Math.sqrt(a2), 0.01, i);
          d2.exponentialRampToValueAtTime(r, p2 + c3), d2.exponentialRampToValueAtTime(1, p2 + c3 + s2);
        },
        0,
        t - 0.01
      );
    }
    connectToOutput(t) {
      t.connect(this.summingNode);
    }
  };
  var po2 = class {
    constructor(t) {
      __publicField(this, "channelMerger");
      __publicField(this, "destinationGain");
      __publicField(this, "connectToDestination", (t, n2 = [0, 1]) => {
        const o = new StereoPannerNode(this.audioContext);
        t.connect(o);
        const a2 = new ChannelSplitterNode(this.audioContext, {
          numberOfOutputs: o.channelCount
        });
        o.connect(a2), n2.forEach((c3, s2) => {
          a2.connect(this.channelMerger, s2 % o.channelCount, c3 % this.audioContext.destination.channelCount);
        });
      });
      this.audioContext = t, this.initializeAudio();
    }
    initializeAudio() {
      const t = this.audioContext, n2 = t.destination.maxChannelCount;
      this.audioContext.destination.channelCount = n2, this.channelMerger = new ChannelMergerNode(t, { numberOfInputs: t.destination.channelCount }), this.destinationGain = new GainNode(t), this.channelMerger.connect(this.destinationGain), this.destinationGain.connect(t.destination);
    }
    reset() {
      this.disconnect(), this.initializeAudio();
    }
    disconnect() {
      this.channelMerger.disconnect(), this.destinationGain.disconnect(), this.destinationGain = null, this.channelMerger = null;
    }
  };
  var uo2 = class {
    constructor(t) {
      __publicField(this, "audioContext");
      __publicField(this, "output");
      __publicField(this, "nodes", {});
      __publicField(this, "buses", {});
      this.audioContext = t, this.output = new po2(t);
    }
    reset() {
      Object.values(this.nodes).forEach((t) => {
        t.disconnect();
      }), Object.values(this.buses).forEach((t) => {
        t.disconnect();
      }), this.nodes = {}, this.buses = {}, this.output.reset();
    }
    duck(t, n2, o = 0, a2 = 0.1, c3 = 1) {
      const s2 = [t].flat(), d2 = [o].flat(), l2 = [a2].flat(), i = [c3].flat();
      s2.forEach((p2, r) => {
        const h = this.nodes[p2];
        if (h == null) {
          ct3(new Error(`duck target orbit ${p2} does not exist`), "superdough");
          return;
        }
        const u3 = d2[r] ?? d2[0], m3 = Math.max(l2[r] ?? l2[0], 2e-3), G4 = i[r] ?? i[0];
        h.duck(n2, u3, m3, G4);
      });
    }
    getOrbit(t, n2) {
      return this.nodes[t] == null && (this.nodes[t] = new ro2(this.audioContext), this.output.connectToDestination(this.nodes[t].output, n2)), this.nodes[t];
    }
    getBus(t) {
      return this.buses[t] == null && (this.buses[t] = lt3(this.audioContext)), this.buses[t];
    }
  };
  var gt3 = Object.freeze({
    NONE: 0,
    ASYM: 1,
    MIRROR: 2,
    BENDP: 3,
    BENDM: 4,
    BENDMP: 5,
    SYNC: 6,
    QUANT: 7,
    FOLD: 8,
    PWM: 9,
    ORBIT: 10,
    SPIN: 11,
    CHAOS: 12,
    PRIMES: 13,
    BINARY: 14,
    BROWNIAN: 15,
    RECIPROCAL: 16,
    WORMHOLE: 17,
    LOGISTIC: 18,
    SIGMOID: 19,
    FRACTAL: 20,
    FLIP: 21
  });
  var it3 = /* @__PURE__ */ new Set();
  function ho2() {
    it3.clear();
  }
  async function mo2(e, t, n2 = 2048) {
    const o = `${e},${n2}`;
    if (!it3.has(o)) {
      const c3 = (await bo2(e, t)).getChannelData(0), s2 = c3.length, d2 = Math.max(1, Math.floor(s2 / n2)), l2 = new Array(d2);
      for (let i = 0; i < d2; i++) {
        const p2 = i * n2;
        l2[i] = c3.subarray(p2, p2 + n2);
      }
      return it3.add(o), { frames: l2, frameLen: n2, numFrames: d2, key: o };
    }
    return { frameLen: n2, key: o };
  }
  function Go2(e, t) {
    var n2 = 1024;
    if (e < n2) return e + " B";
    var o = ["KiB", "MiB", "GiB", "TiB", "PiB", "EiB", "ZiB", "YiB"], a2 = -1;
    do
      e /= n2, ++a2;
    while (e >= n2);
    return e.toFixed(1) + " " + o[a2];
  }
  function Xo2(e) {
    const t = new DataView(e);
    let n2 = 12;
    for (; n2 + 8 <= t.byteLength; ) {
      const o = String.fromCharCode(t.getUint8(n2), t.getUint8(n2 + 1), t.getUint8(n2 + 2), t.getUint8(n2 + 3)), a2 = t.getUint32(n2 + 4, true);
      if (o === "fmt ")
        return t.getUint32(n2 + 12, true);
      n2 += 8 + a2 + (a2 & 1);
    }
    return null;
  }
  async function yo2(e) {
    const t = Xo2(e) || 44100;
    return await new OfflineAudioContext(1, 1, t).decodeAudioData(e);
  }
  var nt2 = {};
  var bo2 = (e, t) => {
    if (e = e.replace("#", "%23"), !nt2[e]) {
      j3(`[wavetable] load table ${t}..`, "load-table", { url: e });
      const n2 = Date.now();
      nt2[e] = fetch(e).then((o) => o.arrayBuffer()).then(async (o) => {
        const a2 = Date.now() - n2, c3 = Go2(o.byteLength);
        return j3(`[wavetable] load table ${t}... done! loaded ${c3} in ${a2}ms`, "loaded-table", { url: e }), await yo2(o);
      });
    }
    return nt2[e];
  };
  function qt3(e, t = "") {
    if (!e.startsWith("github:"))
      throw new Error('expected "github:" at the start of pseudoUrl');
    let [n2, o] = e.split("github:");
    return o = o.endsWith("/") ? o.slice(0, -1) : o, o.split("/").length === 2 && (o += "/main"), `https://raw.githubusercontent.com/${o}/${t}`;
  }
  var Nt3 = (e, t, n2, o = {}) => (t = e._base || t, Object.entries(e).forEach(([a2, c3]) => {
    if (a2 === "_base") return false;
    if (typeof c3 == "string" && (c3 = [c3]), typeof c3 != "object")
      throw new Error("wrong json format for " + a2);
    let s2 = t;
    s2.startsWith("github:") && (s2 = qt3(s2, "")), c3 = c3.map((d2) => s2 + d2).filter((d2) => d2.toLowerCase().endsWith(".wav") ? true : (j3(`[wavetable] skipping ${d2} -- wavetables must be ".wav" format`), false)), c3.length && _t3(a2, c3, { baseUrl: t, frameLen: n2 });
  }));
  function _t3(e, t, n2) {
    ce3(
      e,
      (o, a2, c3, s2) => Zo2(o, a2, c3, t, s2, n2?.frameLen ?? 2048),
      {
        type: "wavetable",
        tables: t,
        ...n2
      }
    );
  }
  var Ao2 = async (e, t, n2, o = {}) => {
    if (n2 !== void 0) return Nt3(n2, e, t);
    e.startsWith("github:") && (e = qt3(e, "strudel.json")), e.startsWith("local:") && (e = "http://localhost:5432");
    const a2 = Jt3(e);
    if (typeof fetch == "function" && !(typeof fetch > "u"))
      return fetch(e).then((c3) => c3.json()).then((c3) => Nt3(c3, a2, t, o)).catch((c3) => {
        throw console.error(c3), new Error(`error loading "${e}"`);
      });
  };
  async function Zo2(e, t, n2, o, a2, c3) {
    const { s: s2, n: d2 = 0, duration: l2, clip: i } = t, p2 = z2(), [r, h, u3, m3] = $3([t.attack, t.decay, t.sustain, t.release]);
    let { warpmode: G4 } = t;
    typeof G4 == "string" && (G4 = gt3[G4.toUpperCase()] ?? gt3.NONE);
    const b2 = Xe3(t), { url: f4, label: y3 } = It3(t, o), M2 = await mo2(f4, y3, c3);
    let Z5 = e + l2;
    i !== void 0 && (Z5 = Math.min(e + i * l2, Z5));
    const W6 = Z5 + m3, S5 = W6 + 0.01, Q4 = {
      begin: e,
      end: S5,
      frequency: b2,
      freqspread: t.detune,
      position: t.wt,
      warp: t.warp,
      warpMode: G4,
      voices: Math.max(t.unison ?? 1, 1),
      panspread: t.spread,
      phaserand: t.wtphaserand ?? t.unison > 1 ? 1 : 0
    }, N5 = we3("wavetable", () => new AudioWorkletNode(p2, "wavetable-oscillator-processor", { outputChannelCount: [2] }));
    if (Object.entries(Q4).forEach(([Ye4, oe3]) => {
      const me5 = N5.parameters.get(Ye4), Ee4 = oe3 !== void 0 ? oe3 : me5.defaultValue;
      me5.value = Ee4;
    }), N5.port.postMessage({ type: "initialize", payload: M2 }), p2.currentTime > e) {
      j3(`[wavetable] still loading sound "${s2}:${d2}"`, "highlight");
      return;
    }
    const g3 = [t.wtattack, t.wtdecay, t.wtsustain, t.wtrelease], C6 = [t.warpattack, t.warpdecay, t.warpsustain, t.warprelease], K4 = N5.parameters, I3 = K4.get("position"), k6 = K4.get("warp");
    let O2 = t.wtrate;
    t.wtsync != null && (O2 = a2 * t.wtsync);
    const w5 = zt3(
      p2,
      I3,
      e,
      W6,
      {
        offset: t.wt,
        amount: t.wtenv,
        defaultAmount: 0.5,
        shape: "linear",
        values: g3,
        holdEnd: Z5,
        defaultValues: [0, 0.5, 0, 0.1]
      },
      {
        frequency: O2,
        depth: t.wtdepth,
        defaultDepth: 0.5,
        shape: t.wtshape,
        skew: t.wtskew,
        dcoffset: t.wtdc ?? 0
      }
    );
    let E4 = t.warprate;
    t.warpsync != null && (E4 = E4 = a2 * t.warpsync);
    const ee5 = zt3(
      p2,
      k6,
      e,
      W6,
      {
        offset: t.warp,
        amount: t.warpenv,
        defaultAmount: 0.5,
        shape: "linear",
        values: C6,
        holdEnd: Z5,
        defaultValues: [0, 0.5, 0, 0.1]
      },
      {
        frequency: E4,
        depth: t.warpdepth,
        defaultDepth: 0.5,
        shape: t.warpshape,
        skew: t.warpskew,
        dcoffset: t.warpdc ?? 0
      }
    ), he5 = Te3(N5.parameters.get("detune"), t, e), Re3 = je3(N5.parameters.get("frequency"), t, e), Qe3 = p2.createGain(), de4 = N5.connect(Qe3);
    _2(de4.gain, r, h, u3, m3, 0, 0.3, e, Z5, "linear"), He2(N5.parameters.get("detune"), t, e, Z5);
    const be5 = {
      node: de4,
      nodes: {
        source: [N5],
        wt_lfo: [w5],
        warp_lfo: [ee5],
        ...Re3?.nodes,
        ...he5?.nodes
      }
    }, ve5 = pe3(
      p2,
      () => {
        ht2(N5), he5?.stop(), Re3?.stop(), Y3(w5), Y3(ee5), n2();
      },
      e,
      S5
    );
    return be5.stop = (Ye4) => {
      ve5.stop(Ye4);
    }, be5;
  }
  var $t3 = 128;
  var rt3 = "System Standard";
  var en3 = $t3;
  function Wo2(e) {
    en3 = parseInt(e) ?? $t3;
  }
  var tn2 = false;
  function fo2(e) {
    tn2 = e == true;
  }
  var ae2 = map();
  function ce3(e, t, n2 = {}) {
    e = e.toLowerCase().replace(/\s+/g, "_"), ae2.setKey(e, { onTrigger: t, data: n2 });
  }
  var nn2 = (e) => e;
  function ie3(e) {
    return nn2(e);
  }
  function qo2(e) {
    nn2 = e;
  }
  function pt3(e) {
    for (const n2 in e)
      e[n2.toLowerCase()] = e[n2];
    const t = ae2.get();
    for (const n2 in t) {
      const [o, a2] = n2.split("_");
      if (!a2) continue;
      const c3 = e[o];
      if (c3) {
        if (typeof c3 == "string")
          t[`${c3}_${a2}`.toLowerCase()] = t[n2];
        else if (Array.isArray(c3))
          for (const s2 of c3)
            t[`${s2}_${a2}`.toLowerCase()] = t[n2];
      }
    }
    ae2.set({ ...t });
  }
  async function Mo2(e) {
    const n2 = await (await fetch(e)).json();
    pt3(n2);
  }
  async function _o2(...e) {
    switch (e.length) {
      case 1:
        return typeof e[0] == "string" ? Mo2(e[0]) : pt3(e[0]);
      case 2:
        return pt3({ [e[0]]: e[1] });
      default:
        throw new Error("aliasMap expects 1 or 2 arguments, received " + e.length);
    }
  }
  function $o2(e, t) {
    if (Me3(e) == null) {
      j3("soundAlias: original sound not found");
      return;
    }
    ae2.setKey(t, Me3(e));
  }
  function Me3(e) {
    return typeof e != "string" ? (console.warn(`getSound: expected string got "${e}". fall back to triangle`), ae2.get().triangle) : ae2.get()[e.toLowerCase()];
  }
  var Vo2 = async () => {
    await navigator.mediaDevices.getUserMedia({ audio: true });
    let e = await navigator.mediaDevices.enumerateDevices();
    e = e.filter((n2) => n2.kind === "audiooutput" && n2.deviceId !== "default");
    const t = /* @__PURE__ */ new Map();
    return t.set(rt3, ""), e.forEach((n2) => {
      t.set(n2.label, n2.deviceId);
    }), t;
  };
  var Ce3 = {
    s: "triangle",
    gain: 0.8,
    postgain: 1,
    density: ".03",
    channels: [1, 2],
    phaserdepth: 0.75,
    shapevol: 1,
    distortvol: 1,
    distorttype: 0,
    delay: 0,
    busgain: 1,
    byteBeatExpression: "0",
    delayfeedback: 0.5,
    delaysync: 3 / 16,
    orbit: 1,
    i: 1,
    velocity: 1,
    fft: 8,
    tremolodepth: 1,
    tremolophase: 0,
    release: 0.01
  };
  var Lo2 = Object.freeze({ ...Ce3 });
  function ec2(e, t) {
    Ce3[e] = t;
  }
  function tc2() {
    Ce3 = { ...Lo2 };
  }
  var bt3 = new Map(Object.entries(Ce3));
  function on2(e, t) {
    bt3.set(e, t);
  }
  function U3(e) {
    return bt3.get(e);
  }
  function nc2(e) {
    Object.keys(e).forEach((t) => {
      on2(t, e[t]);
    });
  }
  function xo2() {
    bt3 = new Map(Object.entries(Ce3));
  }
  function oc2(e) {
    xo2(), e === "1.0" && on2("fanchor", 0.5);
  }
  var cc2 = () => ae2.set({});
  var cn2 = [];
  function ac2(e) {
    cn2.push(e);
  }
  var Je2;
  function zo2() {
    if (!Je2) {
      const e = z2(), t = cn2.concat([Un2]);
      Je2 = Promise.all(t.map((n2) => e.audioWorklet.addModule(n2))).then(
        () => Je2 = void 0
      );
    }
    return Je2;
  }
  async function Ro2(e = {}) {
    const {
      disableWorklets: t = false,
      maxPolyphony: n2,
      audioDeviceName: o = rt3,
      multiChannelOrbits: a2 = false
    } = e;
    if (Wo2(n2), fo2(a2), ho2(), typeof window > "u")
      return;
    const c3 = z2();
    if (o != null && o != rt3)
      try {
        const d2 = (await Vo2()).get(o), l2 = (d2 ?? "").length > 0;
        c3.sinkId !== d2 && l2 && await c3.setSinkId(d2), j3(
          `[superdough] Audio Device set to ${o}, it might take a few seconds before audio plays on all output channels`
        );
      } catch {
        j3("[superdough] failed to set audio interface", "warning");
      }
    if (!c3 instanceof OfflineAudioContext && await c3.resume(), t) {
      j3("[superdough]: AudioWorklets disabled with disableWorklets");
      return;
    }
    try {
      await zo2(), j3("[superdough] AudioWorklets loaded");
    } catch (s2) {
      console.warn("could not load AudioWorklet effects", s2);
    }
    j3("[superdough] ready");
  }
  var ot3;
  async function sc2(e) {
    return ot3 || (ot3 = new Promise((t) => {
      document.addEventListener("mousedown", async function n2() {
        document.removeEventListener("mousedown", n2), await Ro2(e), t();
      });
    })), ot3;
  }
  var ye3;
  function Zt3() {
    return ye3 == null && (ye3 = new uo2(z2())), ye3;
  }
  function dc2(e) {
    return ye3 = e, ye3;
  }
  function lc2(e, t) {
    Zt3().output.connectToDestination(e, t);
  }
  function Yo2(e, t, n2 = 1, o = 0.5, a2 = 1e3, c3 = 2e3) {
    const s2 = z2(), d2 = Fe2(s2, { frequency: n2, depth: c3 * 2, begin: e, end: t }), l2 = 1;
    let i = 282;
    const p2 = [];
    for (let r = 0; r < l2; r++) {
      const h = we3("filter", () => s2.createBiquadFilter());
      h.type = "notch", h.gain.value = 1, h.frequency.value = a2 + i, h.Q.value = 2 - Math.min(Math.max(o * 2, 0), 1.9), d2.connect(h.detune), i += 282, p2.push(h);
    }
    return { filterChain: p2, lfo: d2 };
  }
  function So2(e) {
    e = e ?? 0;
    const t = ["12db", "ladder", "24db"];
    return typeof e == "number" ? t[Math.floor(Pt3(e, t.length))] : e;
  }
  var ne3 = {};
  var Le2 = {};
  function Ko2(e, t = 1024, n2 = 0.5) {
    if (!ne3[e] || ne3[e].context != z2()) {
      const o = z2().createAnalyser();
      o.fftSize = t, o.smoothingTimeConstant = n2, ne3[e] = o, Le2[e] = new Float32Array(ne3[e].frequencyBinCount);
    }
    return ne3[e].fftSize !== t && (ne3[e].fftSize = t, Le2[e] = new Float32Array(ne3[e].frequencyBinCount)), ne3[e];
  }
  function ic2(e = "time", t = 1) {
    const n2 = {
      time: () => ne3[t]?.getFloatTimeDomainData(Le2[t]),
      frequency: () => ne3[t]?.getFloatFrequencyData(Le2[t])
    }[e];
    if (!n2)
      throw new Error(`getAnalyzerData: ${e} not supported. use one of ${Object.keys(n2).join(", ")}`);
    return n2(), Le2[t];
  }
  function rc2() {
    ye3?.reset(), ne3 = {}, Le2 = {};
  }
  var Ne2 = /* @__PURE__ */ new Map();
  function Ht2(e) {
    return (Array.isArray(e) ? e : [e]).map((t) => t - 1);
  }
  var go2 = class {
    constructor() {
      this.audioNodes = [], this.tails = [];
    }
    connect(...t) {
      return t.forEach((n2) => {
        this.tails.forEach((o) => {
          o.connect(n2);
        });
      }), this.tails = t, this.audioNodes.push(...t), this;
    }
    connectOne(t, n2) {
      return this.tails[t].connect(n2), this.tails[t] = n2, this.audioNodes.push(n2), this;
    }
    releaseNodes() {
      this.audioNodes.forEach((t) => hn2(t) ? ht2(t) : Y3(t)), this.audioNodes = [], this.tails = [];
    }
  };
  var No2 = async (e, t, n2, o = 0.5, a2 = 0.5) => {
    const c3 = { main: {} }, s2 = z2(), d2 = Zt3();
    let { stretch: l2 } = e;
    if (l2 != null && (t = t - 0.04), typeof e != "object")
      throw new Error(
        `expected hap.value to be an object, but got "${e}". Hint: append .note() or .s() to the end`,
        "error"
      );
    if (e.duration = n2, t < s2.currentTime) {
      console.warn(
        `[superdough]: cannot schedule sounds in the past (target: ${t.toFixed(2)}, now: ${s2.currentTime.toFixed(2)})`
      );
      return;
    }
    let {
      s: i = U3("s"),
      bank: p2,
      source: r,
      postgain: h = U3("postgain"),
      duckorbit: u3,
      duckonset: m3,
      duckattack: G4,
      duckdepth: b2,
      djf: f4,
      release: y3 = U3("release"),
      dry: M2,
      delay: Z5 = U3("delay"),
      delayfeedback: W6 = U3("delayfeedback"),
      delaysync: S5 = U3("delaysync"),
      delaytime: Q4,
      orbit: F4 = U3("orbit"),
      bus: N5,
      busgain: g3 = U3("busgain"),
      room: C6,
      roomfade: K4,
      roomlp: I3,
      roomdim: k6,
      roomsize: O2,
      ir: w5,
      irspeed: E4,
      irbegin: ee5,
      i: he5 = U3("i"),
      analyze: Re3,
      // analyser wet
      fft: Qe3 = U3("fft"),
      // fftSize 0 - 10
      FX: de4 = [],
      FXrelease: be5
    } = e;
    Q4 = Q4 ?? Lt3(S5, o);
    const ve5 = Ht2(
      tn2 && F4 > 0 ? [F4 * 2 - 1, F4 * 2] : U3("channels")
    ), Ye4 = e.channels != null ? Ht2(e.channels) : ve5, oe3 = d2.getOrbit(F4, Ye4);
    u3 != null && d2.duck(u3, t, m3, G4, b2), h = ie3(h), Z5 = ie3(Z5), g3 = ie3(g3);
    const me5 = t + n2, Ee4 = Math.max(y3, be5 ?? 0), le3 = me5 + Ee4, Oe4 = Math.round(Math.random() * 1e6);
    for (let R5 = 0; R5 <= Ne2.size - en3; R5++) {
      const X = Ne2.entries().next(), v2 = X.value[1].deref(), L5 = X.value[0], P3 = t + 0.25;
      v2?.node?.gain?.linearRampToValueAtTime(0, P3), v2?.stop?.(P3), Ne2.delete(L5);
    }
    if (["-", "~", "_"].includes(i))
      return;
    p2 && i && (i = `${p2}_${i}`, e.s = i);
    const x2 = new go2();
    let Se4;
    if (r)
      Se4 = r(t, e, n2, o), c3.main.source = [Se4];
    else if (Me3(i)) {
      const { onTrigger: R5 } = Me3(i), v2 = await R5(t, e, () => pe3(
        s2,
        () => {
          x2.releaseNodes(), Ne2.delete(Oe4);
        },
        0,
        le3
      ), o);
      v2 && (Se4 = v2.node, Ne2.set(Oe4, new WeakRef(v2)), c3.main = { ...c3.main, ...v2.nodes });
    } else
      throw new Error(`sound ${i} not found! Is it loaded?`);
    if (!Se4)
      return;
    if (s2.currentTime > t) {
      j3("[webaudio] skip hap: still loading", s2.currentTime - t);
      return;
    }
    x2.connect(Se4), de4 = [...de4, e];
    for (let [R5, X] of Object.entries(de4)) {
      const v2 = R5 == de4.length - 1 ? "main" : R5;
      c3[v2] ?? (c3[v2] = {});
      const L5 = c3[v2];
      let {
        gain: P3 = U3("gain"),
        velocity: te4 = U3("velocity"),
        shapevol: De3 = U3("shapevol"),
        distorttype: sn2 = U3("distorttype"),
        distortvol: Ae4 = U3("distortvol"),
        tremolodepth: ke4 = U3("tremolodepth"),
        phaserdepth: Wt3 = U3("phaserdepth"),
        delay: ft2 = U3("delay"),
        delayfeedback: Pe3 = U3("delayfeedback"),
        delaysync: dn2 = U3("delaysync"),
        delaytime: Ie2,
        i: ln2 = U3("i")
      } = X;
      if (P3 = ie3(re3(P3, 1)), De3 = ie3(De3), Ae4 = ie3(Ae4), te4 = ie3(te4), ke4 = ie3(ke4), P3 *= te4, Ie2 = Ie2 ?? Lt3(dn2, o), X.workletSrc !== void 0) {
        const V4 = q3(s2, "generic-processor", {}, { outputChannelCount: [2] });
        x2.connect(V4);
        const H5 = X.workletSrc.replace(/\bpat\[(\d+)\]/g, (A4, Ke3) => X.workletInputs[Ke3]).replaceAll("sFreq", Xe3(e)).replaceAll("sGate", `cc('strudel-gate-${Oe4}')`), { src: B5, ugens: J4, registers: D4 } = compileKabel(H5);
        V4.port.postMessage({ src: B5, schema: { ugens: J4, registers: D4 }, start: t, gateEnd: me5, end: le3 });
      }
      if (X.stretch !== void 0) {
        const V4 = q3(s2, "phase-vocoder-processor", { pitchFactor: X.stretch });
        x2.connect(V4), L5.stretch = [V4];
      }
      if (X.transient !== void 0) {
        const V4 = q3(
          s2,
          "transient-processor",
          {},
          {
            processorOptions: {
              attack: X.transient,
              sustain: X.transsustain,
              begin: t,
              end: le3
            }
          }
        );
        x2.connect(V4), L5.transient = V4;
      }
      const Mt3 = T2(P3);
      L5.gain = [Mt3], x2.connect(Mt3);
      const qe4 = So2(e.ftype), Ze3 = (V4) => xn2(s2, t, me5, V4, o, a2);
      if (X.cutoff !== void 0) {
        const H5 = et3(X, {
          frequency: "cutoff",
          q: "resonance",
          attack: "lpattack",
          decay: "lpdecay",
          sustain: "lpsustain",
          release: "lprelease",
          env: "lpenv",
          anchor: "fanchor",
          model: "ftype",
          drive: "drive",
          rate: "lprate",
          sync: "lpsync",
          depth: "lpdepth",
          depthfrequency: "lpdepthfrequency",
          shape: "lpshape",
          dcoffset: "lpdc",
          skew: "lpskew"
        });
        H5.type = "lowpass";
        const { filter: B5, lfo: J4 } = Ze3(H5);
        if (L5.lpf = [B5], L5.lpf_lfo = [J4], x2.connect(B5), J4 && x2.audioNodes.push(J4), qe4 === "24db") {
          const { filter: D4, lfo: A4 } = Ze3(H5);
          L5.lpf.push(D4), L5.lpf_lfo.push(A4), x2.connect(D4), A4 && x2.audioNodes.push(A4);
        }
      }
      if (X.hcutoff !== void 0) {
        const H5 = et3(X, {
          frequency: "hcutoff",
          q: "hresonance",
          attack: "hpattack",
          decay: "hpdecay",
          sustain: "hpsustain",
          release: "hprelease",
          env: "hpenv",
          anchor: "fanchor",
          model: "ftype",
          drive: "drive",
          rate: "hprate",
          sync: "hpsync",
          depth: "hpdepth",
          depthfrequency: "hpdepthfrequency",
          shape: "hpshape",
          dcoffset: "hpdc",
          skew: "hpskew"
        });
        H5.type = "highpass";
        const { filter: B5, lfo: J4 } = Ze3(H5);
        if (L5.hpf = [B5], L5.hpf_lfo = [J4], J4 && x2.audioNodes.push(J4), x2.connect(B5), qe4 === "24db") {
          const { filter: D4, lfo: A4 } = Ze3(H5);
          L5.hpf.push(D4), L5.hpf_lfo.push(A4), x2.connect(D4), A4 && x2.audioNodes.push(A4);
        }
      }
      if (X.bandf !== void 0) {
        const H5 = et3(X, {
          frequency: "bandf",
          q: "bandq",
          attack: "bpattack",
          decay: "bpdecay",
          sustain: "bpsustain",
          release: "bprelease",
          env: "bpenv",
          anchor: "fanchor",
          model: "ftype",
          drive: "drive",
          rate: "bprate",
          sync: "bpsync",
          depth: "bpdepth",
          depthfrequency: "bpdepthfrequency",
          shape: "bpshape",
          dcoffset: "bpdc",
          skew: "bpskew"
        });
        H5.type = "bandpass";
        const { filter: B5, lfo: J4 } = Ze3(H5);
        if (L5.bpf = [B5], L5.bpf_lfo = [J4], x2.connect(B5), J4 && x2.audioNodes.push(J4), qe4 === "24db") {
          const { filter: D4, lfo: A4 } = Ze3(H5);
          L5.bpf.push(D4), L5.bpf_lfo.push(A4), x2.connect(D4), A4 && x2.audioNodes.push(A4);
        }
      }
      if (X.vowel !== void 0) {
        const V4 = s2.createVowelFilter(X.vowel);
        L5.vowel = V4.filters, x2.connect(V4);
      }
      if (X.coarse !== void 0) {
        const V4 = q3(s2, "coarse-processor", { coarse: X.coarse });
        L5.coarse = [V4], x2.connect(V4);
      }
      if (X.crush !== void 0) {
        const V4 = q3(s2, "crush-processor", { crush: X.crush });
        L5.crush = [V4], x2.connect(V4);
      }
      if (X.shape !== void 0) {
        const V4 = q3(s2, "shape-processor", { shape: X.shape, postgain: De3 });
        L5.shape = [V4], x2.connect(V4);
      }
      if (X.distort !== void 0) {
        const V4 = Cn2(X.distort, Ae4, sn2);
        L5.distort = [V4], x2.connect(V4);
      }
      let _e4 = X.tremolo;
      if (X.tremolosync != null && (_e4 = o * X.tremolosync), _e4 !== void 0) {
        const V4 = Math.max(1 - ke4, 0), H5 = new GainNode(s2, { gain: V4 }), B5 = a2 / o, J4 = Fe2(s2, {
          skew: X.tremoloskew ?? (X.tremoloshape != null ? 0.5 : 1),
          frequency: _e4,
          depth: ke4,
          time: B5,
          dcoffset: 0,
          shape: X.tremoloshape,
          phaseoffset: X.tremolophase,
          min: 0,
          max: 1,
          curve: 1.5,
          begin: t,
          end: le3
        });
        L5.tremolo = [J4], L5.tremolo_gain = [H5], J4.connect(H5.gain), x2.audioNodes.push(J4), x2.connect(H5);
      }
      if (X.compressor !== void 0) {
        const V4 = Ln2(
          s2,
          X.compressor,
          X.compressorRatio,
          X.compressorKnee,
          X.compressorAttack,
          X.compressorRelease
        );
        L5.compressor = [V4], x2.connect(V4);
      }
      if (X.pan !== void 0) {
        const V4 = s2.createStereoPanner();
        L5.pan = [V4], V4.pan.value = 2 * X.pan - 1, x2.connect(V4);
      }
      if (X.phaserrate !== void 0 && Wt3 > 0) {
        const { filterChain: V4, lfo: H5 } = Yo2(
          t,
          le3,
          X.phaserrate,
          Wt3,
          X.phasercenter,
          X.phasersweep
        );
        L5.phaser = [...V4], L5.phaser_lfo = [H5], V4.forEach((B5) => x2.connect(B5)), x2.audioNodes.push(H5);
      }
      if (v2 !== "main" && ft2 > 0 && Ie2 > 0 && Pe3 > 0) {
        const V4 = T2(1);
        Pe3 = se2(Pe3, 0, 0.98);
        const H5 = s2.createFeedbackDelay(1, Ie2, Pe3), B5 = T2(ft2), J4 = T2(X.dry ?? 1), D4 = new GainNode(s2, { gain: 1, channelCount: 2, channelCountMode: "explicit" });
        x2.connect(V4).connect(J4, H5).connectOne(1, B5).connect(D4), x2.audioNodes.push(H5.feedbackGain, H5.delayGain), L5.delay = [H5], L5.delay_mix = [B5];
      }
      if (v2 !== "main" && X.room > 0) {
        let V4;
        if (X.ir !== void 0) {
          let Ke3, We3 = Me3(X.ir);
          Array.isArray(We3) ? Ke3 = We3.data.samples[X.i % We3.data.samples.length] : typeof We3 == "object" && (Ke3 = Object.values(We3.data.samples).flat()[ln2 % Object.values(We3.data.samples).length]), V4 = await dt3(Ke3, s2, X.ir, 0);
        }
        const H5 = T2(1), B5 = s2.createReverb(
          X.roomsize,
          X.roomfade,
          X.roomlp,
          X.roomdim,
          V4,
          X.irspeed,
          X.irbegin
        ), J4 = T2(X.room), D4 = T2(X.dry ?? 1), A4 = new GainNode(s2, { gain: 1, channelCount: 2, channelCountMode: "explicit" });
        x2.connect(H5).connect(D4, B5).connectOne(1, J4).connect(A4), L5.room = [B5], L5.room_mix = [J4];
      }
    }
    if (be5 !== void 0 && be5 > y3) {
      const R5 = T2(1);
      R5.gain.setValueAtTime(1, me5 + y3), R5.gain.linearRampToValueAtTime(0, le3), x2.connect(R5);
    }
    const Ge2 = new GainNode(s2, { gain: h });
    if (c3.main.post = [Ge2], x2.connect(Ge2), Z5 > 0 && Q4 > 0 && W6 > 0) {
      const R5 = oe3.getDelay(Q4, W6, t);
      c3.main.delay = [R5];
      const X = oe3.sendDelay(Ge2, Z5);
      c3.main.delay_mix = [X], x2.audioNodes.push(X);
    }
    if (C6 > 0) {
      let R5;
      if (w5 !== void 0) {
        let L5, P3 = Me3(w5);
        Array.isArray(P3) ? L5 = P3.data.samples[he5 % P3.data.samples.length] : typeof P3 == "object" && (L5 = Object.values(P3.data.samples).flat()[he5 % Object.values(P3.data.samples).length]), R5 = await dt3(L5, s2, w5, 0);
      }
      const X = oe3.getReverb(O2, K4, I3, k6, R5, E4, ee5);
      c3.main.room = [X];
      const v2 = oe3.sendReverb(Ge2, C6);
      c3.main.room_mix = [v2], x2.audioNodes.push(v2);
    }
    if (N5 != null) {
      const R5 = d2.getBus(N5), X = Ue3(Ge2, R5, g3);
      x2.audioNodes.push(X);
    }
    if (f4 != null) {
      const R5 = oe3.getDjf(f4, t);
      c3.main.djf = [R5];
    }
    if (Re3 && !(s2 instanceof OfflineAudioContext)) {
      const R5 = Ko2(Re3, 2 ** (Qe3 + 5)), X = Ue3(Ge2, R5, 1);
      x2.audioNodes.push(X);
    }
    if (M2 != null) {
      M2 = ie3(M2);
      const R5 = new GainNode(s2, { gain: M2 });
      x2.connect(R5), oe3.connectToOutput(R5);
    } else
      oe3.connectToOutput(Ge2);
    de4.forEach((R5, X) => {
      const v2 = X === de4.length - 1 ? "main" : X;
      if (R5.lfo)
        for (const L5 of R5.lfo.__ids) {
          const P3 = R5.lfo[L5];
          P3.fxi ?? (P3.fxi = v2);
          const te4 = On2(
            L5,
            {
              ...P3,
              cps: o,
              cycle: a2,
              begin: t,
              end: le3
            },
            c3
          );
          te4 && x2.audioNodes.push(te4);
        }
      if (R5.env)
        for (const L5 of R5.env.__ids) {
          const P3 = R5.env[L5];
          P3.fxi ?? (P3.fxi = v2);
          const te4 = Dn2(
            L5,
            {
              ...P3,
              begin: t,
              end: le3
            },
            c3
          );
          te4 && x2.audioNodes.push(te4);
        }
      if (R5.bmod)
        for (const L5 of R5.bmod.__ids) {
          const P3 = R5.bmod[L5];
          P3.fxi ?? (P3.fxi = v2);
          const { toCleanup: te4 } = An2({ ...P3, begin: t, end: le3 }, c3, ye3);
          x2.audioNodes.push(...te4);
        }
    });
  };
  var pc2 = (e, t, n2, o) => {
    No2(t, e - n2, t.duration / o, o);
  };
  var Ho2 = ["triangle", "square", "sawtooth", "sine", "user", "one"];
  var To2 = [
    ["tri", "triangle"],
    ["sqr", "square"],
    ["saw", "sawtooth"],
    ["sin", "sine"]
  ];
  function wo2(e, t) {
    const n2 = e, o = new Float32Array(t);
    for (let a2 = 0; a2 < t; a2++) {
      const c3 = a2 * 2 / t - 1;
      o[a2] = Math.tanh(c3 * n2);
    }
    return o;
  }
  function uc2() {
    [...Ho2].forEach((e) => {
      ce3(
        e,
        (t, n2, o) => {
          const [a2, c3, s2, d2] = $3(
            [n2.attack, n2.decay, n2.sustain, n2.release],
            "linear",
            [1e-3, 0.05, 0.6, 0.01]
          ), l2 = T2(0.3), i = Co2(e, t, n2, () => {
            Y3(l2), o();
          }), { node: p2, nodes: r, stop: h, triggerRelease: u3 } = i, { duration: m3 } = n2, G4 = T2(1), b2 = p2.connect(l2).connect(G4), f4 = t + m3;
          _2(b2.gain, a2, c3, s2, d2, 0, 1, t, f4, "linear");
          const y3 = f4 + d2 + 0.01;
          return u3?.(y3), h(y3), {
            node: b2,
            nodes: r,
            stop: (M2) => {
              h(M2);
            }
          };
        },
        { type: "synth", prebake: true }
      );
    }), ce3(
      "sbd",
      (e, t, n2) => {
        const { duration: o, decay: a2 = 0.5, pdecay: c3 = 0.5, penv: s2 = 36, clip: d2 } = t, l2 = z2(), i = 0.02, p2 = 1.2, r = 0.025, h = 1, u3 = l2.createOscillator();
        u3.type = "triangle", u3.frequency.value = Xe3(t, 29), u3.detune.setValueAtTime(s2 * 100, 0), u3.detune.setValueAtTime(s2 * 100, e), u3.detune.exponentialRampToValueAtTime(1e-3, e + c3);
        const m3 = T2(1);
        m3.gain.setValueAtTime(1, e + i), m3.gain.exponentialRampToValueAtTime(1e-3, e + i + a2), u3.start(e);
        const G4 = at3("brown", e, 2), b2 = T2(1);
        b2.gain.setValueAtTime(p2, e), b2.gain.exponentialRampToValueAtTime(1e-3, e + r);
        const f4 = new WaveShaperNode(l2);
        f4.curve = wo2(2, l2.sampleRate);
        const y3 = T2(h);
        ue3(u3, () => {
          Y3(u3), Y3(m3), Y3(f4), Y3(G4.node), Y3(b2), Y3(y3), n2();
        });
        const M2 = u3.connect(f4).connect(m3).connect(y3);
        G4.node.connect(b2).connect(y3);
        let W6 = e + a2 + 0.01;
        return d2 != null && (W6 = Math.min(e + d2 * o, W6)), y3.gain.setValueAtTime(h, W6 - 0.01), y3.gain.linearRampToValueAtTime(0, W6), u3.stop(W6), G4.stop(W6), {
          node: M2,
          nodes: { source: [u3] },
          stop: (S5) => {
            u3.stop(S5);
          }
        };
      },
      { type: "synth", prebake: true }
    ), ce3(
      "supersaw",
      (e, t, n2) => {
        const o = z2();
        let { duration: a2, n: c3, unison: s2 = 5, spread: d2 = 0.6, detune: l2 } = t;
        l2 = l2 ?? c3 ?? 0.18;
        const i = Xe3(t), [p2, r, h, u3] = $3(
          [t.attack, t.decay, t.sustain, t.release],
          "linear",
          [1e-3, 0.05, 0.6, 0.01]
        ), m3 = e + a2, G4 = m3 + u3 + 0.01, b2 = se2(s2, 1, 100);
        let f4 = b2 > 1 ? se2(d2, 0, 1) : 0;
        const y3 = {
          frequency: i,
          begin: e,
          end: G4,
          freqspread: l2,
          voices: b2,
          panspread: f4
        }, Z5 = we3("supersaw", () => new AudioWorkletNode(o, "supersaw-oscillator", { outputChannelCount: [2] }));
        Object.entries(y3).forEach(([g3, C6]) => {
          const K4 = Z5.parameters.get(g3), I3 = C6 !== void 0 ? C6 : K4.defaultValue;
          K4.value = I3;
        }), Z5.port.postMessage({ type: "initialize" });
        const W6 = 1 / Math.sqrt(b2);
        He2(Z5.parameters.get("detune"), t, e, m3);
        const S5 = Te3(Z5.parameters.get("detune"), t, e), Q4 = je3(Z5.parameters.get("frequency"), t, e);
        let F4 = T2(1);
        F4 = Z5.connect(F4), _2(F4.gain, p2, r, h, u3, 0, 0.3 * W6, e, m3, "linear");
        let N5 = pe3(
          o,
          () => {
            ht2(Z5), n2(), Q4?.stop(), S5?.stop();
          },
          e,
          G4
        );
        return {
          node: F4,
          nodes: { source: [Z5], ...Q4?.nodes, ...S5?.nodes },
          stop: (g3) => {
            N5.stop(g3);
          }
        };
      },
      { prebake: true, type: "synth" }
    ), ce3(
      "bytebeat",
      (e, t, n2) => {
        const o = [
          "(t%255 >= t/255%255)*255",
          "(t*(t*8%60 <= 300)|(-t)*(t*4%512 < 256))+t/400",
          "t",
          "t*(t >> 10^t)",
          "t&128",
          "t&t>>8",
          "((t%255+t%128+t%64+t%32+t%16+t%127.8+t%64.8+t%32.8+t%16.8)/3)",
          "((t%64+t%63.8+t%64.15+t%64.35+t%63.5)/1.25)",
          "(t&(t>>7)-t)",
          "(sin(t*PI/128)*127+127)",
          "((t^t/2+t+64*(sin((t*PI/64)+(t*PI/32768))+64))%128*2)",
          "((t^t/2+t+64*(cos >> 0))%127.85*2)",
          "((t^t/2+t+64)%128*2)",
          "(((t * .25)^(t * .25)/100+(t * .25))%128)*2",
          "((t^t/2+t+64)%7 * 24)"
        ], { n: a2 = 0 } = t, c3 = Xe3(t), { byteBeatExpression: s2 = o[a2 % o.length], byteBeatStartTime: d2 } = t, l2 = z2();
        let { duration: i } = t;
        const [p2, r, h, u3] = $3(
          [t.attack, t.decay, t.sustain, t.release],
          "linear",
          [1e-3, 0.05, 0.6, 0.01]
        ), m3 = e + i, G4 = m3 + u3 + 0.01;
        let b2 = q3(
          l2,
          "byte-beat-processor",
          {
            frequency: c3,
            begin: e,
            end: G4
          },
          {
            outputChannelCount: [2]
          }
        );
        b2.port.postMessage({ codeText: s2, byteBeatStartTime: d2, frequency: c3 });
        let f4 = T2(1);
        f4 = b2.connect(f4), _2(f4.gain, p2, r, h, u3, 0, 1, e, m3, "linear");
        let y3 = pe3(
          l2,
          () => {
            Y3(b2), n2();
          },
          e,
          G4
        );
        return {
          node: f4,
          source: b2,
          stop: (M2) => {
            y3.stop(M2);
          }
        };
      },
      { prebake: true, type: "synth" }
    ), ce3(
      "pulse",
      (e, t, n2) => {
        const o = z2();
        let { pwrate: a2, pwsweep: c3 } = t;
        c3 == null && (a2 != null ? c3 = 0.3 : c3 = 0), a2 == null && c3 != null && (a2 = 1);
        let { duration: s2, pw: d2 = 0.5 } = t;
        const l2 = Xe3(t), [i, p2, r, h] = $3(
          [t.attack, t.decay, t.sustain, t.release],
          "linear",
          [1e-3, 0.05, 0.6, 0.01]
        ), u3 = e + s2, m3 = u3 + h + 0.01;
        let G4 = q3(
          o,
          "pulse-oscillator",
          {
            frequency: l2,
            begin: e,
            end: m3,
            pulsewidth: d2
          },
          {
            outputChannelCount: [2]
          }
        );
        He2(G4.parameters.get("detune"), t, e, u3);
        const b2 = Te3(G4.parameters.get("detune"), t, e), f4 = je3(G4.parameters.get("frequency"), t, e);
        let y3 = T2(1);
        y3 = G4.connect(y3), _2(y3.gain, i, p2, r, h, 0, 1, e, u3, "linear");
        let M2;
        c3 != 0 && (M2 = Fe2(o, { frequency: a2, depth: c3, begin: e, end: m3 }), M2.connect(G4.parameters.get("pulsewidth")));
        let Z5 = pe3(
          o,
          () => {
            Y3(G4), Y3(M2), n2(), f4?.stop(), b2?.stop();
          },
          e,
          m3
        );
        return {
          node: y3,
          nodes: { source: [G4], pw_lfo: [M2], ...f4?.nodes, ...b2?.nodes },
          stop: (W6) => {
            Z5.stop(W6);
          }
        };
      },
      { prebake: true, type: "synth" }
    ), ce3(
      "bus",
      (e, t, n2) => {
        const o = z2(), [a2, c3, s2, d2] = $3(
          [t.attack, t.decay, t.sustain, t.release],
          "linear",
          [1e-3, 0.05, 1, 0.01]
        ), l2 = e + t.duration, i = l2 + d2 + 0.01, p2 = Zt3().getBus(t.n ?? 0), r = p2.connect(T2(0));
        _2(r.gain, a2, c3, s2, d2, 0, 1, e, l2, "linear");
        const h = pe3(
          o,
          () => {
            p2.disconnect(r), n2();
          },
          e,
          i
        );
        return {
          node: r,
          nodes: { source: [p2] },
          stop: (u3) => {
            h.stop(u3);
          }
        };
      },
      { prebake: true, type: "input" }
    ), [...Ut3].forEach((e) => {
      ce3(
        e,
        (t, n2, o) => {
          const [a2, c3, s2, d2] = $3(
            [n2.attack, n2.decay, n2.sustain, n2.release],
            "linear",
            [1e-3, 0.05, 0.6, 0.01]
          );
          let l2, { density: i } = n2;
          l2 = at3(e, t, i);
          let { node: p2, stop: r, triggerRelease: h } = l2;
          const u3 = T2(0.3), { duration: m3 } = n2;
          ue3(p2, () => {
            Y3(p2), Y3(u3), o();
          });
          const G4 = T2(1);
          let b2 = p2.connect(u3).connect(G4);
          const f4 = t + m3;
          _2(b2.gain, a2, c3, s2, d2, 0, 1, t, f4, "linear");
          const y3 = f4 + d2 + 0.01;
          return h?.(y3), r(y3), {
            node: b2,
            nodes: { source: [p2] },
            stop: (M2) => {
              r(M2);
            }
          };
        },
        { type: "synth", prebake: true }
      );
    }), To2.forEach(([e, t]) => ae2.set({ ...ae2.get(), [e]: ae2.get()[t] }));
  }
  var Tt2 = 2 * Math.PI;
  function Fo2(e, t, n2) {
    e = typeof e == "object" ? e : new Float32Array(e).fill(1);
    const a2 = e.length, c3 = new Float32Array(a2 + 1), s2 = new Float32Array(a2 + 1), d2 = z2(), l2 = d2.createOscillator(), i = {
      sawtooth: (r) => [0, -1 / r],
      square: (r) => [0, r % 2 === 0 ? 0 : 1 / r],
      triangle: (r) => [r % 2 === 0 ? 0 : 1 / (r * r), 0],
      user: (r) => [0, 1]
    };
    if (!i[n2])
      throw new Error(`unknown wave type ${n2}`);
    for (let r = 0; r < a2; r++) {
      const h = e[r], [u3, m3] = i[n2](r + 1), G4 = t?.[r] ?? 0;
      let b2 = u3 * h, f4 = m3 * h;
      if (G4 !== 0) {
        const y3 = Math.cos(Tt2 * G4), M2 = Math.sin(Tt2 * G4);
        b2 = y3 * b2 - M2 * f4, f4 = M2 * b2 + y3 * f4;
      }
      c3[r + 1] = b2, s2[r + 1] = f4;
    }
    const p2 = d2.createPeriodicWave(c3, s2);
    return l2.setPeriodicWave(p2), l2;
  }
  function Co2(e, t, n2, o) {
    const { duration: a2, noise: c3 = 0 } = n2, s2 = n2.partials ?? n2.n;
    let d2;
    if (e === "user" && !s2 && (j3(
      "[superdough] Synth 'user' was selected, but partials not specified. Defaulting to triangle. Use pat.partials to setup custom waveform"
    ), e = "triangle"), e = e === "user" && !s2 ? "triangle" : e, e === "one")
      return d2 = new ConstantSourceNode(z2(), { offset: 1 }), d2.start(t), {
        node: d2,
        nodes: { source: d2 },
        stop: (r) => d2?.stop(r)
      };
    !s2 || s2?.length === 0 || e === "sine" ? (d2 = z2().createOscillator(), d2.type = e || "triangle") : d2 = Fo2(s2, n2.phases, e), d2.frequency.value = Xe3(n2);
    const l2 = Te3(d2.detune, n2, t);
    He2(d2.detune, n2, t, t + a2);
    const i = je3(d2.frequency, n2, t);
    let p2;
    return c3 && (p2 = un2(d2, c3, t)), ue3(d2, () => {
      p2?.teardown(), Y3(d2), Y3(p2?.node), o();
    }), d2.start(t), {
      node: p2?.node || d2,
      nodes: { source: [d2], ...l2?.nodes, ...i?.nodes },
      stop: (r) => {
        i.stop(r), l2?.stop(r), p2?.stop(r), d2.stop(r);
      },
      triggerRelease: (r) => {
      }
    };
  }
  function ko2(e = 1, t = 0.05, n2 = 220, o = 0, a2 = 0, c3 = 0.1, s2 = 0, d2 = 1, l2 = 0, i = 0, p2 = 0, r = 0, h = 0, u3 = 0, m3 = 0, G4 = 0, b2 = 0, f4 = 1, y3 = 0, M2 = 0) {
    let Z5 = Math.PI * 2, W6 = z2().sampleRate, S5 = (he5) => he5 > 0 ? 1 : -1, Q4 = l2 *= 500 * Z5 / W6 / W6, F4 = n2 *= (1 + t * 2 * Math.random() - t) * Z5 / W6, N5 = [], g3 = 0, C6 = 0, K4 = 0, I3 = 1, k6 = 0, O2 = 0, w5 = 0, E4, ee5;
    for (o = o * W6 + 9, y3 *= W6, a2 *= W6, c3 *= W6, b2 *= W6, i *= 500 * Z5 / W6 ** 3, m3 *= Z5 / W6, p2 *= Z5 / W6, r *= W6, h = h * W6 | 0, ee5 = o + y3 + a2 + c3 + b2 | 0; K4 < ee5; N5[K4++] = w5)
      ++O2 % (G4 * 100 | 0) || (w5 = s2 ? s2 > 1 ? s2 > 2 ? s2 > 3 ? Math.sin((g3 % Z5) ** 3) : Math.max(Math.min(Math.tan(g3), 1), -1) : 1 - (2 * g3 / Z5 % 2 + 2) % 2 : 1 - 4 * Math.abs(Math.round(g3 / Z5) - g3 / Z5) : Math.sin(g3), w5 = (h ? 1 - M2 + M2 * Math.sin(Z5 * K4 / h) : 1) * S5(w5) * Math.abs(w5) ** d2 * // curve 0=square, 2=pointy
      e * 1 * // envelope
      (K4 < o ? K4 / o : K4 < o + y3 ? 1 - (K4 - o) / y3 * (1 - f4) : K4 < o + y3 + a2 ? f4 : K4 < ee5 - b2 ? (ee5 - K4 - b2) / c3 * // release falloff
      f4 : 0), w5 = b2 ? w5 / 2 + (b2 > K4 ? 0 : (K4 < ee5 - b2 ? 1 : (ee5 - K4) / b2) * // release delay
      N5[K4 - b2 | 0] / 2) : w5), E4 = (n2 += l2 += i) * // frequency
      Math.cos(m3 * C6++), g3 += E4 - E4 * u3 * (1 - (Math.sin(K4) + 1) * 1e9 % 2), I3 && ++I3 > r && (n2 += p2, F4 += p2, I3 = 0), h && !(++k6 % h) && (n2 = F4, l2 = Q4, I3 || (I3 = 1));
    return N5;
  }
  var Po2 = (e, t) => {
    let {
      s: n2,
      note: o = 36,
      freq: a2,
      //
      zrand: c3 = 0,
      attack: s2 = 0,
      decay: d2 = 0,
      sustain: l2 = 0.8,
      release: i = 0.1,
      curve: p2 = 1,
      slide: r = 0,
      deltaSlide: h = 0,
      pitchJump: u3 = 0,
      pitchJumpTime: m3 = 0,
      lfo: G4 = 0,
      znoise: b2 = 0,
      zmod: f4 = 0,
      zcrush: y3 = 0,
      zdelay: M2 = 0,
      tremolo: Z5 = 0,
      duration: W6 = 0.2,
      zzfx: S5
    } = e;
    const Q4 = Math.max(W6 - s2 - d2, 0);
    typeof o == "string" && (o = Be3(o)), !a2 && typeof o == "number" && (a2 = kt3(o)), n2 = n2.replace("z_", "");
    const F4 = ["sine", "triangle", "sawtooth", "tan", "noise"].indexOf(n2) || 0;
    p2 = n2 === "square" ? 0 : p2;
    const g3 = (
      /* ZZFX. */
      ko2(...S5 || [
        0.25,
        // volume
        c3,
        a2,
        s2,
        Q4,
        i,
        F4,
        p2,
        r,
        h,
        u3,
        m3,
        G4,
        b2,
        f4,
        y3,
        M2,
        l2,
        // sustain volume!
        d2,
        Z5
      ])
    ), C6 = z2(), K4 = C6.createBuffer(1, g3.length, C6.sampleRate);
    K4.getChannelData(0).set(g3);
    const I3 = z2().createBufferSource();
    return I3.buffer = K4, I3.start(t), {
      node: I3
    };
  };
  function hc2() {
    ["zzfx", "z_sine", "z_sawtooth", "z_triangle", "z_square", "z_tan", "z_noise"].forEach((e) => {
      ce3(
        e,
        (t, n2, o) => {
          const { node: a2 } = Po2({ s: e, ...n2 }, t);
          return ue3(a2, () => {
            Y3(a2), o();
          }), {
            node: a2,
            nodes: { source: [a2] },
            stop: () => {
            }
          };
        },
        { type: "synth", prebake: true }
      );
    });
  }
  var xe3;
  async function Io2(e, t) {
    const n2 = `dsp-worklet-${Date.now()}`, o = `${t}
let __q = []; // trigger queue
class MyProcessor extends AudioWorkletProcessor {
  constructor() {
    super();
    this.t = 0;
    this.stopped = false;
    this.port.onmessage = (e) => {
      if(e.data==='stop') {
        this.stopped = true;
      } else if(e.data?.dough) {
        __q.push(e.data)
      } else {
        msg?.(e.data)
      }
    };
  }
  process(inputs, outputs, parameters) {
    const output = outputs[0];
    if(__q.length) {
      for(let i=0;i<__q.length;++i) {
        const deadline = __q[i].time-currentTime;
        if(deadline<=0) {
          trigger(__q[i].dough)
          __q.splice(i,1)
        }
      }
    }
    for (let i = 0; i < output[0].length; i++) {
      const out = dsp(this.t / sampleRate);
      output.forEach((channel) => {
        channel[i] = out;
      });
      this.t++;
    }
  return !this.stopped;
  }
}
registerProcessor('${n2}', MyProcessor);
`, c3 = `data:text/javascript;base64,${btoa(o)}`;
    await e.audioWorklet.addModule(c3);
    const s2 = new AudioWorkletNode(e, n2);
    return { node: s2, stop: () => s2.port.postMessage("stop") };
  }
  var an2 = () => {
    xe3 && (xe3?.stop(), xe3?.node?.disconnect());
  };
  typeof window < "u" && window.addEventListener("message", (e) => {
    e.data === "strudel-stop" ? an2() : e.data?.dough && xe3?.node.port.postMessage(e.data);
  });
  var mc2 = async (e) => {
    const t = z2();
    an2(), xe3 = await Io2(t, e), xe3.node.connect(t.destination);
  };
  function Gc2(e, t, n2, o) {
    window.postMessage({ time: o, dough: e.value, currentTime: t, duration: e.duration, cps: n2 });
  }

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/supradough/dist/index.mjs
  var H2 = "data:text/javascript;base64,dmFyIGF0PU9iamVjdC5kZWZpbmVQcm9wZXJ0eTt2YXIgaHQ9KHUsbSxmKT0+bSBpbiB1P2F0KHUsbSx7ZW51bWVyYWJsZTohMCxjb25maWd1cmFibGU6ITAsd3JpdGFibGU6ITAsdmFsdWU6Zn0pOnVbbV09Zjt2YXIgZT0odSxtLGYpPT5odCh1LHR5cGVvZiBtIT0ic3ltYm9sIj9tKyIiOm0sZik7KGZ1bmN0aW9uKCl7InVzZSBzdHJpY3QiO2NvbnN0IHU9dHlwZW9mIHNhbXBsZVJhdGU8InUiP3NhbXBsZVJhdGU6NDhlMyxtPU1hdGguUEkvdSxmPTEvdTtsZXQgVj1oPT5NYXRoLnBvdyhoLDIpO2Z1bmN0aW9uIF8oaCl7cmV0dXJuIFYoaCl9ZnVuY3Rpb24gTyhoLHMsdCl7Y29uc3QgaT1NYXRoLnNpbigoMS10KSouNSpNYXRoLlBJKSxuPU1hdGguc2luKHQqLjUqTWF0aC5QSSk7cmV0dXJuIGgqaStzKm59Y2xhc3MgZ3tjb25zdHJ1Y3Rvcigpe2UodGhpcywicGhhc2UiLDApfXVwZGF0ZShzKXtjb25zdCB0PU1hdGguc2luKHRoaXMucGhhc2UqMipNYXRoLlBJKTtyZXR1cm4gdGhpcy5waGFzZT0odGhpcy5waGFzZStzL3UpJTEsdH19Y2xhc3MgSXtjb25zdHJ1Y3Rvcigpe2UodGhpcywicGhhc2UiLDApfXVwZGF0ZShzKXtyZXR1cm4gdGhpcy5waGFzZSs9ZipzLHRoaXMucGhhc2UlMSoyLTF9fWZ1bmN0aW9uIE0oaCxzKXtyZXR1cm4gaDxzPyhoLz1zLGgraC1oKmgtMSk6aD4xLXM/KGg9KGgtMSkvcyxoKmgraCtoKzEpOjB9Y2xhc3MgU3tjb25zdHJ1Y3RvcihzPXt9KXt0aGlzLnBoYXNlPXMucGhhc2U/PzB9dXBkYXRlKHMpe2NvbnN0IHQ9cy91O2xldCBpPU0odGhpcy5waGFzZSx0KSxuPTIqdGhpcy5waGFzZS0xLWk7cmV0dXJuIHRoaXMucGhhc2UrPXQsdGhpcy5waGFzZT4xJiYodGhpcy5waGFzZS09MSksbn19ZnVuY3Rpb24gVChoLHMsdCl7cmV0dXJuIGg8Mj8wOigobixsLHIpPT5yKihsLW4pK24pKC1zKi41LHMqLjUsdC8oaC0xKSl9ZnVuY3Rpb24geihoLHMpe3JldHVybiBoKk1hdGgucG93KDIscy8xMil9Y2xhc3MgRntjb25zdHJ1Y3RvcihzPXt9KXt0aGlzLnZvaWNlcz1zLnZvaWNlcz8/NSx0aGlzLmZyZXFzcHJlYWQ9cy5mcmVxc3ByZWFkPz8uMix0aGlzLnBhbnNwcmVhZD1zLnBhbnNwcmVhZD8/LjQsdGhpcy5waGFzZT1uZXcgRmxvYXQzMkFycmF5KHRoaXMudm9pY2VzKS5tYXAoKCk9Pk1hdGgucmFuZG9tKCkpfXVwZGF0ZShzKXtjb25zdCB0PU1hdGguc3FydCgxLXRoaXMucGFuc3ByZWFkKSxpPU1hdGguc3FydCh0aGlzLnBhbnNwcmVhZCk7bGV0IG49MCxsPTA7Zm9yKGxldCByPTA7cjx0aGlzLnZvaWNlcztyKyspe2NvbnN0IGE9eihzLFQodGhpcy52b2ljZXMsdGhpcy5mcmVxc3ByZWFkLHIpKS91LGM9KHImMSk9PTE7bGV0IGQ9dDtjJiYoZD1pKTtsZXQgYj1NKHRoaXMucGhhc2Vbcl0sYSksRT0yKnRoaXMucGhhc2Vbcl0tMS1iO249bitFKmQsbD1sK0UqZCx0aGlzLnBoYXNlW3JdKz1hLHRoaXMucGhhc2Vbcl0+MSYmKHRoaXMucGhhc2Vbcl0tPTEpfXJldHVybiBuK2x9fWNsYXNzIGt7Y29uc3RydWN0b3IoKXtlKHRoaXMsInBoYXNlIiwwKX11cGRhdGUocyl7dGhpcy5waGFzZSs9ZipzO2xldCB0PXRoaXMucGhhc2UlMTtyZXR1cm4odDwuNT8yKnQ6MS0yKih0LS41KSkqMi0xfX1jbGFzcyBxe2NvbnN0cnVjdG9yKCl7ZSh0aGlzLCJzMCIsMCk7ZSh0aGlzLCJzMSIsMCl9dXBkYXRlKHMsdCxpPTApe2k9TWF0aC5tYXgoaSwwKSx0PU1hdGgubWluKHQsMmU0KTtjb25zdCBuPTIqTWF0aC5zaW4odCptKSxyPTEtTWF0aC5wb3coLjUsKGkrLjEyNSkvLjEyNSkqbjtyZXR1cm4gdGhpcy5zMD1yKnRoaXMuczAtbip0aGlzLnMxK24qcyx0aGlzLnMxPXIqdGhpcy5zMStuKnRoaXMuczAsdGhpcy5zMX19Y2xhc3MgQ3tjb25zdHJ1Y3RvcihzPTApe3RoaXMucGhhc2U9c31zYXcocyx0KXtsZXQgaT0odGhpcy5waGFzZStzKSUxLG49TShpLHQpO3JldHVybiAyKmktMS1ufXVwZGF0ZShzLHQ9LjUpe2NvbnN0IGk9cy91O2xldCBuPXRoaXMuc2F3KDAsaSktdGhpcy5zYXcodCxpKTtyZXR1cm4gdGhpcy5waGFzZT0odGhpcy5waGFzZStpKSUxLG4rdCoyLTF9fWNsYXNzIEx7Y29uc3RydWN0b3IoKXtlKHRoaXMsInBoYXNlIiwwKX11cGRhdGUocyx0PS41KXtyZXR1cm4gdGhpcy5waGFzZSs9ZipzLHRoaXMucGhhc2UlMTx0PzE6LTF9fWNsYXNzIFB7Y29uc3RydWN0b3IoKXtlKHRoaXMsInVwZGF0ZSIscz0+TWF0aC5yYW5kb20oKTxzKmY/TWF0aC5yYW5kb20oKTowKX19Y2xhc3MgTnt1cGRhdGUoKXtyZXR1cm4gTWF0aC5yYW5kb20oKSoyLTF9fWNsYXNzIEd7Y29uc3RydWN0b3IoKXt0aGlzLm91dD0wfXVwZGF0ZSgpe2xldCBzPU1hdGgucmFuZG9tKCkqMi0xO3JldHVybiB0aGlzLm91dD0odGhpcy5vdXQrLjAyKnMpLzEuMDIsdGhpcy5vdXR9fWNsYXNzIGp7Y29uc3RydWN0b3IoKXt0aGlzLmIwPTAsdGhpcy5iMT0wLHRoaXMuYjI9MCx0aGlzLmIzPTAsdGhpcy5iND0wLHRoaXMuYjU9MCx0aGlzLmI2PTB9dXBkYXRlKCl7Y29uc3Qgcz1NYXRoLnJhbmRvbSgpKjItMTt0aGlzLmIwPS45OTg4Nip0aGlzLmIwK3MqLjA1NTUxNzksdGhpcy5iMT0uOTkzMzIqdGhpcy5iMStzKi4wNzUwNzU5LHRoaXMuYjI9Ljk2OSp0aGlzLmIyK3MqLjE1Mzg1Mix0aGlzLmIzPS44NjY1KnRoaXMuYjMrcyouMzEwNDg1Nix0aGlzLmI0PS41NSp0aGlzLmI0K3MqLjUzMjk1MjIsdGhpcy5iNT0tLjc2MTYqdGhpcy5iNS1zKi4wMTY4OTg7Y29uc3QgdD10aGlzLmIwK3RoaXMuYjErdGhpcy5iMit0aGlzLmIzK3RoaXMuYjQrdGhpcy5iNSt0aGlzLmI2K3MqLjUzNjI7cmV0dXJuIHRoaXMuYjY9cyouMTE1OTI2LHQqLjExfX1jbGFzcyBCe2NvbnN0cnVjdG9yKCl7ZSh0aGlzLCJwaGFzZSIsMSl9dXBkYXRlKHMpe3RoaXMucGhhc2UrPWYqcztsZXQgdD10aGlzLnBoYXNlPj0xPzE6MDtyZXR1cm4gdGhpcy5waGFzZT10aGlzLnBoYXNlJTEsdH19ZnVuY3Rpb24gUihoLHMsdCxpPTEpe2lmKGg8PTApcmV0dXJuIHM7aWYoaD49MSlyZXR1cm4gdDtsZXQgbjtyZXR1cm4gaT09PTA/bj1oOmk+MD9uPU1hdGgucG93KGgsaSk6bj0xLU1hdGgucG93KDEtaCwtaSkscysodC1zKSpufWNsYXNzIHZ7Y29uc3RydWN0b3Iocz17fSl7dGhpcy5zdGF0ZT0ib2ZmIix0aGlzLnN0YXJ0VGltZT0wLHRoaXMuc3RhcnRWYWw9MCx0aGlzLmRlY2F5Q3VydmU9cy5kZWNheUN1cnZlPz8xfXVwZGF0ZShzLHQsaSxuLGwscil7c3dpdGNoKHRoaXMuc3RhdGUpe2Nhc2Uib2ZmIjpyZXR1cm4gdD4wJiYodGhpcy5zdGF0ZT0iYXR0YWNrIix0aGlzLnN0YXJ0VGltZT1zLHRoaXMuc3RhcnRWYWw9MCksMDtjYXNlImF0dGFjayI6e2xldCBwPXMtdGhpcy5zdGFydFRpbWU7cmV0dXJuIHA+aT8odGhpcy5zdGF0ZT0iZGVjYXkiLHRoaXMuc3RhcnRUaW1lPXMsMSk6UihwL2ksdGhpcy5zdGFydFZhbCwxLDEpfWNhc2UiZGVjYXkiOntsZXQgcD1zLXRoaXMuc3RhcnRUaW1lLGE9UihwL24sMSxsLC10aGlzLmRlY2F5Q3VydmUpO3JldHVybiB0PD0wPyh0aGlzLnN0YXRlPSJyZWxlYXNlIix0aGlzLnN0YXJ0VGltZT1zLHRoaXMuc3RhcnRWYWw9YSxhKTpwPm4/KHRoaXMuc3RhdGU9InN1c3RhaW4iLHRoaXMuc3RhcnRUaW1lPXMsbCk6YX1jYXNlInN1c3RhaW4iOnJldHVybiB0PD0wJiYodGhpcy5zdGF0ZT0icmVsZWFzZSIsdGhpcy5zdGFydFRpbWU9cyx0aGlzLnN0YXJ0VmFsPWwpLGw7Y2FzZSJyZWxlYXNlIjp7bGV0IHA9cy10aGlzLnN0YXJ0VGltZTtpZihwPnIpcmV0dXJuIHRoaXMuc3RhdGU9Im9mZiIsMDtsZXQgYT1SKHAvcix0aGlzLnN0YXJ0VmFsLDAsLXRoaXMuZGVjYXlDdXJ2ZSk7cmV0dXJuIHQ+MCYmKHRoaXMuc3RhdGU9ImF0dGFjayIsdGhpcy5zdGFydFRpbWU9cyx0aGlzLnN0YXJ0VmFsPWEpLGF9fXRocm93ImludmFsaWQgZW52ZWxvcGUgc3RhdGUifX1jb25zdCBXPTEwO2NsYXNzIHh7Y29uc3RydWN0b3IoKXtlKHRoaXMsIndyaXRlSWR4IiwwKTtlKHRoaXMsInJlYWRJZHgiLDApO2UodGhpcywiYnVmZmVyIixuZXcgRmxvYXQzMkFycmF5KFcqdSkpfXdyaXRlKHMsdCl7dGhpcy53cml0ZUlkeD0odGhpcy53cml0ZUlkeCsxKSV0aGlzLmJ1ZmZlci5sZW5ndGgsdGhpcy5idWZmZXJbdGhpcy53cml0ZUlkeF09cztsZXQgaT1NYXRoLm1pbihNYXRoLmZsb29yKHUqdCksdGhpcy5idWZmZXIubGVuZ3RoLTEpO3RoaXMucmVhZElkeD10aGlzLndyaXRlSWR4LWksdGhpcy5yZWFkSWR4PDAmJih0aGlzLnJlYWRJZHgrPXRoaXMuYnVmZmVyLmxlbmd0aCl9dXBkYXRlKHMsdCl7cmV0dXJuIHRoaXMud3JpdGUocyx0KSx0aGlzLmJ1ZmZlclt0aGlzLnJlYWRJZHhdfX1jbGFzcyBYe2NvbnN0cnVjdG9yKCl7ZSh0aGlzLCJkZWxheSIsbmV3IHgpO2UodGhpcywibW9kdWxhdG9yIixuZXcgayl9dXBkYXRlKHMsdCxpLG4sbCl7Y29uc3Qgcj10aGlzLm1vZHVsYXRvci51cGRhdGUobikqbCxwPXRoaXMuZGVsYXkudXBkYXRlKHMsaSooMStyKSk7cmV0dXJuIE8ocyxwLHQpfX1jbGFzcyAke2NvbnN0cnVjdG9yKCl7ZSh0aGlzLCJob2xkIiwwKTtlKHRoaXMsInQiLDApfXVwZGF0ZShzLHQpe3JldHVybiB0aGlzLnQrKyV0PT09MCYmKHRoaXMudD0wLHRoaXMuaG9sZD1zKSx0aGlzLmhvbGR9fWNsYXNzIFV7dXBkYXRlKHMsdCl7dD1NYXRoLm1heCgxLHQpO2NvbnN0IGk9TWF0aC5wb3coMix0LTEpO3JldHVybiBNYXRoLnJvdW5kKHMqaSkvaX19Y2xhc3MgWXt1cGRhdGUocyx0PTAsaT0xKXtpPU1hdGgubWF4KC4wMDEsTWF0aC5taW4oMSxpKSk7Y29uc3Qgbj1NYXRoLmV4cG0xKHQpO3JldHVybigxK24pKnMvKDErbipNYXRoLmFicyhzKSkqaX19Y2xhc3Mgd3tjb25zdHJ1Y3RvcihzLHQsaSl7ZSh0aGlzLCJidWZmZXIiKTtlKHRoaXMsInNhbXBsZVJhdGUiKTtlKHRoaXMsInBvcyIsMCk7ZSh0aGlzLCJzYW1wbGVGcmVxIixBKCkpO3RoaXMuYnVmZmVyPXMsdGhpcy5zYW1wbGVSYXRlPXQsdGhpcy5kdXJhdGlvbj10aGlzLmJ1ZmZlci5sZW5ndGgvdGhpcy5zYW1wbGVSYXRlLHRoaXMuc3BlZWQ9dS90aGlzLnNhbXBsZVJhdGUsaSYmKHRoaXMuc3BlZWQqPXRoaXMuZHVyYXRpb24pfXVwZGF0ZShzKXtpZih0aGlzLnBvcz49dGhpcy5idWZmZXIubGVuZ3RoKXJldHVybiAwO2NvbnN0IHQ9cy90aGlzLnNhbXBsZUZyZXEqdGhpcy5zcGVlZDtsZXQgaT10aGlzLmJ1ZmZlcltNYXRoLmZsb29yKHRoaXMucG9zKV07cmV0dXJuIHRoaXMucG9zPXRoaXMucG9zK3QsaX19ZSh3LCJzYW1wbGVzIixuZXcgTWFwKTtjb25zdCB5PShoLHM9ImxpbmVhciIsdCk9Pntjb25zdFtyLHAsYSxjXT1oO2lmKHI9PW51bGwmJnA9PW51bGwmJmE9PW51bGwmJmM9PW51bGwpcmV0dXJuIHQ/P1suMDAxLC4wMDEsMSwuMDFdO2NvbnN0IGQ9YT8/KHIhPW51bGwmJnA9PW51bGx8fHI9PW51bGwmJnA9PW51bGw/MTouMDAxKTtyZXR1cm5bTWF0aC5tYXgocj8/MCwuMDAxKSxNYXRoLm1heChwPz8wLC4wMDEpLE1hdGgubWluKGQsMSksTWF0aC5tYXgoYz8/MCwuMDEpXX07bGV0IEQ9e3NpbmU6ZyxzYXc6Uyx6YXc6SSxzYXd0b290aDpTLHphd3Rvb3RoOkksc3VwZXJzYXc6Rix0cmk6ayx0cmlhbmdsZTprLHB1bHNlOkMsc3F1YXJlOkMscHVsemU6TCxkdXN0OlAsY3JhY2tsZTpQLGltcHVsc2U6Qix3aGl0ZTpOLGJyb3duOkcscGluazpqfTtjb25zdCBaPXtjaG9ydXM6MCxub3RlOjQ4LHM6InRyaWFuZ2xlIixiYW5rOiIiLGdhaW46MSxwb3N0Z2FpbjoxLHZlbG9jaXR5OjEsZGVuc2l0eToiLjAzIixmdHlwZToiMTJkYiIsZmFuY2hvcjowLHJlc29uYW5jZTowLGhyZXNvbmFuY2U6MCxiYW5kcTowLGNoYW5uZWxzOlsxLDJdLHBoYXNlcmRlcHRoOi43NSxzaGFwZXZvbDoxLGRpc3RvcnR2b2w6MSxkZWxheTowLGJ5dGVCZWF0RXhwcmVzc2lvbjoiMCIsZGVsYXlmZWVkYmFjazouNSxkZWxheXNwZWVkOjEsZGVsYXl0aW1lOi4yNSxvcmJpdDoxLGk6MSxmZnQ6OCx6OiJ0cmlhbmdsZSIscGFuOi41LGZtaDoxLGZtZW52OjAsc3BlZWQ6MSxwdzouNX07bGV0IG89aD0+WltoXTtjb25zdCBIPXtjOjAsZDoyLGU6NCxmOjUsZzo3LGE6OSxiOjExfSxKPXsiIyI6MSxiOi0xLHM6MSxmOi0xfSxLPShoLHM9Myk9Pnt2YXIgYTtsZXRbdCxpPSIiLG49IiJdPSgoYT1TdHJpbmcoaCkubWF0Y2goL14oW2EtZ0EtR10pKFsjYnNmXSopKFswLTldKikkLykpPT1udWxsP3ZvaWQgMDphLnNsaWNlKDEpKXx8W107aWYoIXQpdGhyb3cgbmV3IEVycm9yKCdub3QgYSBub3RlOiAiJytoKyciJyk7Y29uc3QgbD1IW3QudG9Mb3dlckNhc2UoKV0scj0oaT09bnVsbD92b2lkIDA6aS5zcGxpdCgiIikucmVkdWNlKChjLGQpPT5jK0pbZF0sMCkpfHwwO3JldHVybihOdW1iZXIobnx8cykrMSkqMTIrbCtyfSxRPWg9Pk1hdGgucG93KDIsKGgtNjkpLzEyKSo0NDAsQT1oPT4oaD1ofHxvKCJub3RlIiksdHlwZW9mIGg9PSJzdHJpbmciJiYoaD1LKGgsMykpLFEoaCkpO2NsYXNzIHR0e2NvbnN0cnVjdG9yKHMpe2UodGhpcywiaWQiLDApO2UodGhpcywib3V0IixbMCwwXSk7ZSh0aGlzLCJhdHRhY2siKTtlKHRoaXMsImRlY2F5Iik7ZSh0aGlzLCJzdXN0YWluIik7ZSh0aGlzLCJyZWxlYXNlIik7ZSh0aGlzLCJfYmVnaW4iKTtlKHRoaXMsIl9kdXJhdGlvbiIpO2UodGhpcywiX3NvdW5kIik7ZSh0aGlzLCJfY2hhbm5lbHMiLDEpO2UodGhpcywiX2J1ZmZlcnMiKTtlKHRoaXMsInVuaXQiKTtlKHRoaXMsIl9wZW52Iik7ZSh0aGlzLCJwZW52Iik7ZSh0aGlzLCJwYXR0YWNrIik7ZSh0aGlzLCJwZGVjYXkiKTtlKHRoaXMsInBzdXN0YWluIik7ZSh0aGlzLCJwcmVsZWFzZSIpO2UodGhpcywidmliIik7ZSh0aGlzLCJfdmliIik7ZSh0aGlzLCJ2aWJtb2QiKTtlKHRoaXMsIl9mbSIpO2UodGhpcywiZm1oIik7ZSh0aGlzLCJmbWkiKTtlKHRoaXMsIl9mbWVudiIpO2UodGhpcywiZm1hdHRhY2siKTtlKHRoaXMsImZtZGVjYXkiKTtlKHRoaXMsImZtc3VzdGFpbiIpO2UodGhpcywiZm1yZWxlYXNlIik7ZSh0aGlzLCJfbHBlbnYiKTtlKHRoaXMsImxwZW52Iik7ZSh0aGlzLCJscGF0dGFjayIpO2UodGhpcywibHBkZWNheSIpO2UodGhpcywibHBzdXN0YWluIik7ZSh0aGlzLCJscHJlbGVhc2UiKTtlKHRoaXMsIl9ocGVudiIpO2UodGhpcywiaHBlbnYiKTtlKHRoaXMsImhwYXR0YWNrIik7ZSh0aGlzLCJocGRlY2F5Iik7ZSh0aGlzLCJocHN1c3RhaW4iKTtlKHRoaXMsImhwcmVsZWFzZSIpO2UodGhpcywiX2JwZW52Iik7ZSh0aGlzLCJicGVudiIpO2UodGhpcywiYnBhdHRhY2siKTtlKHRoaXMsImJwZGVjYXkiKTtlKHRoaXMsImJwc3VzdGFpbiIpO2UodGhpcywiYnByZWxlYXNlIik7ZSh0aGlzLCJjdXRvZmYiKTtlKHRoaXMsImhjdXRvZmYiKTtlKHRoaXMsImJhbmRmIik7ZSh0aGlzLCJjb2Fyc2UiKTtlKHRoaXMsImNydXNoIik7ZSh0aGlzLCJkaXN0b3J0Iik7ZSh0aGlzLCJmcmVxIik7ZSh0aGlzLCJub3RlIik7ZSh0aGlzLCJfbHBmIik7ZSh0aGlzLCJfaHBmIik7ZSh0aGlzLCJfYnBmIik7ZSh0aGlzLCJfY2hvcnVzIik7ZSh0aGlzLCJfY29hcnNlIik7ZSh0aGlzLCJfY3J1c2giKTtlKHRoaXMsIl9kaXN0b3J0Iik7dmFyIGksbixsLHIscCxhLGM7dGhpcy5mcmVxPz8odGhpcy5mcmVxPUEocy5ub3RlKSksdGhpcy5fYmVnaW49cy5fYmVnaW4sdGhpcy5fZHVyYXRpb249cy5fZHVyYXRpb24sdGhpcy5yZWxlYXNlPXMucmVsZWFzZT8/MDtsZXQgdD10aGlzO2lmKE9iamVjdC5hc3NpZ24odCxzKSx0LnM9dC5zPz9vKCJzIiksdC5nYWluPV8odC5nYWluPz9vKCJnYWluIikpLHQudmVsb2NpdHk9Xyh0LnZlbG9jaXR5Pz9vKCJ2ZWxvY2l0eSIpKSx0LnBvc3RnYWluPV8odC5wb3N0Z2Fpbj8/bygicG9zdGdhaW4iKSksdC5kZW5zaXR5PXQuZGVuc2l0eT8/bygiZGVuc2l0eSIpLHQuZmFuY2hvcj10LmZhbmNob3I/P28oImZhbmNob3IiKSx0LmRyaXZlPXQuZHJpdmU/Py42OSx0LnBoYXNlcmRlcHRoPXQucGhhc2VyZGVwdGg/P28oInBoYXNlcmRlcHRoIiksdC5zaGFwZXZvbD1fKHQuc2hhcGV2b2w/P28oInNoYXBldm9sIikpLHQuZGlzdG9ydHZvbD1fKHQuZGlzdG9ydHZvbD8/bygiZGlzdG9ydHZvbCIpKSx0Lmk9dC5pPz9vKCJpIiksdC5jaG9ydXM9dC5jaG9ydXM/P28oImNob3J1cyIpLHQuZmZ0PXQuZmZ0Pz9vKCJmZnQiKSx0LnBhbj10LnBhbj8/bygicGFuIiksdC5vcmJpdD10Lm9yYml0Pz9vKCJvcmJpdCIpLHQuZm1lbnY9dC5mbWVudj8/bygiZm1lbnYiKSx0LnJlc29uYW5jZT10LnJlc29uYW5jZT8/bygicmVzb25hbmNlIiksdC5ocmVzb25hbmNlPXQuaHJlc29uYW5jZT8/bygiaHJlc29uYW5jZSIpLHQuYmFuZHE9dC5iYW5kcT8/bygiYmFuZHEiKSx0LnNwZWVkPXQuc3BlZWQ/P28oInNwZWVkIiksdC5wdz10LnB3Pz9vKCJwdyIpLFt0LmF0dGFjayx0LmRlY2F5LHQuc3VzdGFpbix0LnJlbGVhc2VdPXkoW3QuYXR0YWNrLHQuZGVjYXksdC5zdXN0YWluLHQucmVsZWFzZV0pLHQuX2hvbGRFbmQ9dC5fYmVnaW4rdC5fZHVyYXRpb24sdC5fZW5kPXQuX2hvbGRFbmQrdC5yZWxlYXNlKy4wMSx0LmZtaSYmKHQucz09PSJzYXcifHx0LnM9PT0ic2F3dG9vdGgiKSYmKHQucz0iemF3IiksRFt0LnNdKXtjb25zdCBkPURbdC5zXTt0Ll9zb3VuZD1uZXcgZCx0Ll9jaGFubmVscz0xfWVsc2UgaWYody5zYW1wbGVzLmhhcyh0LnMpKXtjb25zdCBkPXcuc2FtcGxlcy5nZXQodC5zKTt0Ll9idWZmZXJzPVtdLHQuX2NoYW5uZWxzPWQuY2hhbm5lbHMubGVuZ3RoO2ZvcihsZXQgYj0wO2I8dC5fY2hhbm5lbHM7YisrKXQuX2J1ZmZlcnMucHVzaChuZXcgdyhkLmNoYW5uZWxzW2JdLGQuc2FtcGxlUmF0ZSx0LnVuaXQ9PT0iYyIpKX1lbHNlIGNvbnNvbGUud2Fybigic291bmQgbm90IGxvYWRlZCIsdC5zKTt0LnBlbnYmJih0Ll9wZW52PW5ldyB2KHtkZWNheUN1cnZlOjR9KSxbdC5wYXR0YWNrLHQucGRlY2F5LHQucHN1c3RhaW4sdC5wcmVsZWFzZV09eShbdC5wYXR0YWNrLHQucGRlY2F5LHQucHN1c3RhaW4sdC5wcmVsZWFzZV0pKSx0LnZpYiYmKHQuX3ZpYj1uZXcgZyx0LnZpYm1vZD10LnZpYm1vZD8/bygidmlibW9kIikpLHQuZm1pJiYodC5fZm09bmV3IGcsdC5mbWg9dC5mbWg/P28oImZtaCIpLHQuZm1lbnYmJih0Ll9mbWVudj1uZXcgdih7ZGVjYXlDdXJ2ZToyfSksW3QuZm1hdHRhY2ssdC5mbWRlY2F5LHQuZm1zdXN0YWluLHQuZm1yZWxlYXNlXT15KFt0LmZtYXR0YWNrLHQuZm1kZWNheSx0LmZtc3VzdGFpbix0LmZtcmVsZWFzZV0pKSksdC5fYWRzcj1uZXcgdih7ZGVjYXlDdXJ2ZToyfSksdC5kZWxheT1fKHQuZGVsYXk/P28oImRlbGF5IikpLHQuZGVsYXlmZWVkYmFjaz10LmRlbGF5ZmVlZGJhY2s/P28oImRlbGF5ZmVlZGJhY2siKSx0LmRlbGF5c3BlZWQ9dC5kZWxheXNwZWVkPz9vKCJkZWxheXNwZWVkIiksdC5kZWxheXRpbWU9dC5kZWxheXRpbWU/P28oImRlbGF5dGltZSIpLHQubHBlbnYmJih0Ll9scGVudj1uZXcgdih7ZGVjYXlDdXJ2ZTo0fSksW3QubHBhdHRhY2ssdC5scGRlY2F5LHQubHBzdXN0YWluLHQubHByZWxlYXNlXT15KFt0LmxwYXR0YWNrLHQubHBkZWNheSx0Lmxwc3VzdGFpbix0LmxwcmVsZWFzZV0pKSx0LmhwZW52JiYodC5faHBlbnY9bmV3IHYoe2RlY2F5Q3VydmU6NH0pLFt0LmhwYXR0YWNrLHQuaHBkZWNheSx0Lmhwc3VzdGFpbix0LmhwcmVsZWFzZV09eShbdC5ocGF0dGFjayx0LmhwZGVjYXksdC5ocHN1c3RhaW4sdC5ocHJlbGVhc2VdKSksdC5icGVudiYmKHQuX2JwZW52PW5ldyB2KHtkZWNheUN1cnZlOjR9KSxbdC5icGF0dGFjayx0LmJwZGVjYXksdC5icHN1c3RhaW4sdC5icHJlbGVhc2VdPXkoW3QuYnBhdHRhY2ssdC5icGRlY2F5LHQuYnBzdXN0YWluLHQuYnByZWxlYXNlXSkpLHQuX2Nob3J1cz10LmNob3J1cz9bXTpudWxsLHQuX2xwZj10LmN1dG9mZj9bXTpudWxsLHQuX2hwZj10LmhjdXRvZmY/W106bnVsbCx0Ll9icGY9dC5iYW5kZj9bXTpudWxsLHQuX2NvYXJzZT10LmNvYXJzZT9bXTpudWxsLHQuX2NydXNoPXQuY3J1c2g/W106bnVsbCx0Ll9kaXN0b3J0PXQuZGlzdG9ydD9bXTpudWxsO2ZvcihsZXQgZD0wO2Q8dGhpcy5fY2hhbm5lbHM7ZCsrKShpPXQuX2xwZik9PW51bGx8fGkucHVzaChuZXcgcSksKG49dC5faHBmKT09bnVsbHx8bi5wdXNoKG5ldyBxKSwobD10Ll9icGYpPT1udWxsfHxsLnB1c2gobmV3IHEpLChyPXQuX2Nob3J1cyk9PW51bGx8fHIucHVzaChuZXcgWCksKHA9dC5fY29hcnNlKT09bnVsbHx8cC5wdXNoKG5ldyAkKSwoYT10Ll9jcnVzaCk9PW51bGx8fGEucHVzaChuZXcgVSksKGM9dC5fZGlzdG9ydCk9PW51bGx8fGMucHVzaChuZXcgWSl9dXBkYXRlKHMpe2lmKCF0aGlzLl9zb3VuZCYmIXRoaXMuX2J1ZmZlcnMpcmV0dXJuIDA7bGV0IHQ9KyhzPj10aGlzLl9iZWdpbiYmczw9dGhpcy5faG9sZEVuZCksaT10aGlzLmZyZXEqdGhpcy5zcGVlZDtpZih0aGlzLl9mbSYmdGhpcy5mbWghPT12b2lkIDAmJnRoaXMuZm1pIT09dm9pZCAwKXtsZXQgYT10aGlzLmZtaTtpZih0aGlzLl9mbWVudil7Y29uc3QgYj10aGlzLl9mbWVudi51cGRhdGUocyx0LHRoaXMuZm1hdHRhY2ssdGhpcy5mbWRlY2F5LHRoaXMuZm1zdXN0YWluLHRoaXMuZm1yZWxlYXNlKTthPXRoaXMuZm1lbnYqYiphfWNvbnN0IGM9aSp0aGlzLmZtaCxkPWMqYTtpPWkrdGhpcy5fZm0udXBkYXRlKGMpKmR9aWYodGhpcy5fdmliJiZ0aGlzLnZpYm1vZCE9PXZvaWQgMCYmKGk9aSoyKioodGhpcy5fdmliLnVwZGF0ZSh0aGlzLnZpYikqdGhpcy52aWJtb2QvMTIpKSx0aGlzLl9wZW52JiZ0aGlzLnBlbnYhPT12b2lkIDApe2NvbnN0IGE9dGhpcy5fcGVudi51cGRhdGUocyx0LHRoaXMucGF0dGFjayx0aGlzLnBkZWNheSx0aGlzLnBzdXN0YWluLHRoaXMucHJlbGVhc2UpO2k9aSthKnRoaXMucGVudn1sZXQgbj10aGlzLmN1dG9mZjtpZihuIT09dm9pZCAwJiZ0aGlzLl9scGVudil7Y29uc3QgYT10aGlzLl9scGVudi51cGRhdGUocyx0LHRoaXMubHBhdHRhY2ssdGhpcy5scGRlY2F5LHRoaXMubHBzdXN0YWluLHRoaXMubHByZWxlYXNlKTtuPXRoaXMubHBlbnYqYSpuK259bGV0IGw9dGhpcy5oY3V0b2ZmO2lmKGwhPT12b2lkIDAmJnRoaXMuX2hwZW52JiZ0aGlzLmhwZW52IT09dm9pZCAwKXtjb25zdCBhPXRoaXMuX2hwZW52LnVwZGF0ZShzLHQsdGhpcy5ocGF0dGFjayx0aGlzLmhwZGVjYXksdGhpcy5ocHN1c3RhaW4sdGhpcy5ocHJlbGVhc2UpO2w9MioqdGhpcy5ocGVudiphKmwrbH1sZXQgcj10aGlzLmJhbmRmO2lmKHIhPT12b2lkIDAmJnRoaXMuX2JwZW52JiZ0aGlzLmJwZW52IT09dm9pZCAwKXtjb25zdCBhPXRoaXMuX2JwZW52LnVwZGF0ZShzLHQsdGhpcy5icGF0dGFjayx0aGlzLmJwZGVjYXksdGhpcy5icHN1c3RhaW4sdGhpcy5icHJlbGVhc2UpO3I9MioqdGhpcy5icGVudiphKnIrcn1jb25zdCBwPXRoaXMuX2Fkc3IudXBkYXRlKHMsdCx0aGlzLmF0dGFjayx0aGlzLmRlY2F5LHRoaXMuc3VzdGFpbix0aGlzLnJlbGVhc2UpO2ZvcihsZXQgYT0wO2E8dGhpcy5fY2hhbm5lbHM7YSsrKXtpZih0aGlzLl9zb3VuZCYmdGhpcy5zPT09InB1bHNlIj90aGlzLm91dFthXT10aGlzLl9zb3VuZC51cGRhdGUoaSx0aGlzLnB3KTp0aGlzLl9zb3VuZD90aGlzLm91dFthXT10aGlzLl9zb3VuZC51cGRhdGUoaSk6dGhpcy5fYnVmZmVycyYmKHRoaXMub3V0W2FdPXRoaXMuX2J1ZmZlcnNbYV0udXBkYXRlKGkpKSx0aGlzLm91dFthXT10aGlzLm91dFthXSp0aGlzLmdhaW4qdGhpcy52ZWxvY2l0eSx0aGlzLl9jaG9ydXMpe2NvbnN0IGM9dGhpcy5fY2hvcnVzW2FdLnVwZGF0ZSh0aGlzLm91dFthXSx0aGlzLmNob3J1cywuMDMrLjA1KmEsMSwuMTEpO3RoaXMub3V0W2FdPWMrdGhpcy5vdXRbYV19dGhpcy5fbHBmJiYodGhpcy5fbHBmW2FdLnVwZGF0ZSh0aGlzLm91dFthXSxuLHRoaXMucmVzb25hbmNlKSx0aGlzLm91dFthXT10aGlzLl9scGZbYV0uczEpLHRoaXMuX2hwZiYmKHRoaXMuX2hwZlthXS51cGRhdGUodGhpcy5vdXRbYV0sbCx0aGlzLmhyZXNvbmFuY2UpLHRoaXMub3V0W2FdPXRoaXMub3V0W2FdLXRoaXMuX2hwZlthXS5zMSksdGhpcy5fYnBmJiYodGhpcy5fYnBmW2FdLnVwZGF0ZSh0aGlzLm91dFthXSxyLHRoaXMuYmFuZHEpLHRoaXMub3V0W2FdPXRoaXMuX2JwZlthXS5zMCksdGhpcy5fY29hcnNlJiYodGhpcy5vdXRbYV09dGhpcy5fY29hcnNlW2FdLnVwZGF0ZSh0aGlzLm91dFthXSx0aGlzLmNvYXJzZSkpLHRoaXMuX2NydXNoJiYodGhpcy5vdXRbYV09dGhpcy5fY3J1c2hbYV0udXBkYXRlKHRoaXMub3V0W2FdLHRoaXMuY3J1c2gpKSx0aGlzLl9kaXN0b3J0JiYodGhpcy5vdXRbYV09dGhpcy5fZGlzdG9ydFthXS51cGRhdGUodGhpcy5vdXRbYV0sdGhpcy5kaXN0b3J0LHRoaXMuZGlzdG9ydHZvbCkpLHRoaXMub3V0W2FdPXRoaXMub3V0W2FdKnAsdGhpcy5vdXRbYV09dGhpcy5vdXRbYV0qdGhpcy5wb3N0Z2Fpbix0aGlzLl9idWZmZXJzfHwodGhpcy5vdXRbYV09dGhpcy5vdXRbYV0qLjIpfWlmKHRoaXMuX2NoYW5uZWxzPT09MSYmKHRoaXMub3V0WzFdPXRoaXMub3V0WzBdKSx0aGlzLnBhbiE9PS41KXtjb25zdCBhPXRoaXMucGFuKk1hdGguUEkvMjt0aGlzLm91dFswXT10aGlzLm91dFswXSpNYXRoLmNvcyhhKSx0aGlzLm91dFsxXT10aGlzLm91dFsxXSpNYXRoLnNpbihhKX19fWNsYXNzIHN0e2NvbnN0cnVjdG9yKHM9NDhlMyx0PTApe2UodGhpcywidm9pY2VzIixbXSk7ZSh0aGlzLCJ2aWQiLDApO2UodGhpcywicSIsW10pO2UodGhpcywib3V0IixbMCwwXSk7ZSh0aGlzLCJkZWxheXNlbmQiLFswLDBdKTtlKHRoaXMsImRlbGF5dGltZSIsbygiZGVsYXl0aW1lIikpO2UodGhpcywiZGVsYXlmZWVkYmFjayIsbygiZGVsYXlmZWVkYmFjayIpKTtlKHRoaXMsImRlbGF5c3BlZWQiLG8oImRlbGF5c3BlZWQiKSk7ZSh0aGlzLCJ0IiwwKTt0aGlzLnNhbXBsZVJhdGU9cyx0aGlzLnQ9TWF0aC5mbG9vcih0KnMpLHRoaXMuX2RlbGF5TD1uZXcgeCx0aGlzLl9kZWxheVI9bmV3IHh9bG9hZFNhbXBsZShzLHQsaSl7dy5zYW1wbGVzLnNldChzLHtjaGFubmVsczp0LHNhbXBsZVJhdGU6aX0pfXNjaGVkdWxlU3Bhd24ocyl7aWYocy5fYmVnaW49PT12b2lkIDApdGhyb3cgbmV3IEVycm9yKCJbZG91Z2hdOiBzY2hlZHVsZVNwYXduIGV4cGVjdGVkIF9iZWdpbiB0byBiZSBzZXQiKTtpZihzLl9kdXJhdGlvbj09PXZvaWQgMCl0aHJvdyBuZXcgRXJyb3IoIltkb3VnaF06IHNjaGVkdWxlU3Bhd24gZXhwZWN0ZWQgX2R1cmF0aW9uIHRvIGJlIHNldCIpO3Muc2FtcGxlUmF0ZT10aGlzLnNhbXBsZVJhdGU7Y29uc3QgdD1NYXRoLmZsb29yKHMuX2JlZ2luKnRoaXMuc2FtcGxlUmF0ZSk7dGhpcy5zY2hlZHVsZSh7dGltZTp0LHR5cGU6InNwYXduIixhcmc6c30pfXNwYXduKHMpe3MuaWQ9dGhpcy52aWQrKztjb25zdCB0PW5ldyB0dChzKTt0aGlzLnZvaWNlcy5wdXNoKHQpO2NvbnN0IGk9TWF0aC5jZWlsKHQuX2VuZCp0aGlzLnNhbXBsZVJhdGUpO3RoaXMuc2NoZWR1bGUoe3RpbWU6aSx0eXBlOiJkZXNwYXduIixhcmc6dC5pZH0pfWRlc3Bhd24ocyl7dGhpcy52b2ljZXM9dGhpcy52b2ljZXMuZmlsdGVyKHQ9PnQuaWQhPT1zKX1zY2hlZHVsZShzKXtpZighdGhpcy5xLmxlbmd0aCl7dGhpcy5xLnB1c2gocyk7cmV0dXJufWxldCB0PTA7Zm9yKDt0PHRoaXMucS5sZW5ndGgmJnRoaXMucVt0XS50aW1lPHMudGltZTspdCsrO3RoaXMucS5zcGxpY2UodCwwLHMpfXVwZGF0ZSgpe2Zvcig7dGhpcy5xLmxlbmd0aD4wJiZ0aGlzLnFbMF0udGltZTw9dGhpcy50Oyl0aGlzW3RoaXMucVswXS50eXBlXSh0aGlzLnFbMF0uYXJnKSx0aGlzLnEuc2hpZnQoKTt0aGlzLm91dFswXT0wLHRoaXMub3V0WzFdPTA7Zm9yKGxldCBpPTA7aTx0aGlzLnZvaWNlcy5sZW5ndGg7aSsrKXRoaXMudm9pY2VzW2ldLnVwZGF0ZSh0aGlzLnQvdGhpcy5zYW1wbGVSYXRlKSx0aGlzLm91dFswXSs9dGhpcy52b2ljZXNbaV0ub3V0WzBdLHRoaXMub3V0WzFdKz10aGlzLnZvaWNlc1tpXS5vdXRbMV0sdGhpcy52b2ljZXNbaV0uZGVsYXkmJih0aGlzLmRlbGF5c2VuZFswXSs9dGhpcy52b2ljZXNbaV0ub3V0WzBdKnRoaXMudm9pY2VzW2ldLmRlbGF5LHRoaXMuZGVsYXlzZW5kWzFdKz10aGlzLnZvaWNlc1tpXS5vdXRbMV0qdGhpcy52b2ljZXNbaV0uZGVsYXksdGhpcy5kZWxheXRpbWU9dGhpcy52b2ljZXNbaV0uZGVsYXl0aW1lLHRoaXMuZGVsYXlzcGVlZD10aGlzLnZvaWNlc1tpXS5kZWxheXNwZWVkLHRoaXMuZGVsYXlmZWVkYmFjaz10aGlzLnZvaWNlc1tpXS5kZWxheWZlZWRiYWNrKTtjb25zdCBzPXRoaXMuX2RlbGF5TC51cGRhdGUodGhpcy5kZWxheXNlbmRbMF0sdGhpcy5kZWxheXRpbWUpLHQ9dGhpcy5fZGVsYXlSLnVwZGF0ZSh0aGlzLmRlbGF5c2VuZFsxXSx0aGlzLmRlbGF5dGltZSk7dGhpcy5kZWxheXNlbmRbMF09cyp0aGlzLmRlbGF5ZmVlZGJhY2ssdGhpcy5kZWxheXNlbmRbMV09dCp0aGlzLmRlbGF5ZmVlZGJhY2ssdGhpcy5vdXRbMF0rPXMsdGhpcy5vdXRbMV0rPXQsdGhpcy50Kyt9fWNvbnN0IGV0PShoLHMsdCk9Pk1hdGgubWluKE1hdGgubWF4KGgscyksdCk7Y2xhc3MgaXQgZXh0ZW5kcyBBdWRpb1dvcmtsZXRQcm9jZXNzb3J7Y29uc3RydWN0b3IoKXtzdXBlcigpLHRoaXMuZG91Z2g9bmV3IHN0KHNhbXBsZVJhdGUsY3VycmVudFRpbWUpLHRoaXMucG9ydC5vbm1lc3NhZ2U9cz0+e3MuZGF0YS5zcGF3bj90aGlzLmRvdWdoLnNjaGVkdWxlU3Bhd24ocy5kYXRhLnNwYXduKTpzLmRhdGEuc2FtcGxlP3RoaXMuZG91Z2gubG9hZFNhbXBsZShzLmRhdGEuc2FtcGxlLHMuZGF0YS5jaGFubmVscyxzLmRhdGEuc2FtcGxlUmF0ZSk6cy5kYXRhLnNhbXBsZXM/cy5kYXRhLnNhbXBsZXMuZm9yRWFjaCgoW3QsaSxuXSk9Pnt0aGlzLmRvdWdoLmxvYWRTYW1wbGUodCxpLG4pfSk6Y29uc29sZS5sb2coInVucmVjb2duaXplZCBldmVudCB0eXBlIixzLmRhdGEpfX1wcm9jZXNzKHMsdCxpKXtpZih0aGlzLmRpc2Nvbm5lY3RlZClyZXR1cm4hMTtjb25zdCBuPXRbMF07Zm9yKGxldCBsPTA7bDxuWzBdLmxlbmd0aDtsKyspe3RoaXMuZG91Z2gudXBkYXRlKCk7Zm9yKGxldCByPTA7cjxuLmxlbmd0aDtyKyspbltyXVtsXT1ldCh0aGlzLmRvdWdoLm91dFtyXSwtMSwxKX1yZXR1cm4hMH19cmVnaXN0ZXJQcm9jZXNzb3IoImRvdWdoLXByb2Nlc3NvciIsaXQpfSkoKTsK";
  var u2 = typeof sampleRate < "u" ? sampleRate : 48e3;
  var k2 = Math.PI / u2;
  var n = 1 / u2;
  var us2 = H2;

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/draw/dist/index.mjs
  var Z3 = (t = "test-canvas", e) => {
    let { contextType: n2 = "2d", pixelated: o = false, pixelRatio: a2 = window.devicePixelRatio } = e || {}, r = document.querySelector("#" + t);
    if (!r) {
      r = document.createElement("canvas"), r.id = t, r.width = window.innerWidth * a2, r.height = window.innerHeight * a2, r.style = "pointer-events:none;width:100%;height:100%;position:fixed;top:0;left:0", o && (r.style.imageRendering = "pixelated"), document.body.prepend(r);
      let l2;
      window.addEventListener("resize", () => {
        l2 && clearTimeout(l2), l2 = setTimeout(() => {
          r.width = window.innerWidth * a2, r.height = window.innerHeight * a2;
        }, 200);
      });
    }
    return r.getContext(n2, { willReadFrequently: true });
  };
  var $4 = {};
  function pe4(t) {
    $4[t] !== void 0 && (cancelAnimationFrame($4[t]), delete $4[t]);
  }
  var R2 = {};
  f2.prototype.draw = function(t, e) {
    if (typeof window > "u")
      return this;
    let { id: n2 = 1, lookbehind: o = 0, lookahead: a2 = 0 } = e, r = Math.max(Wy(), 0);
    pe4(n2), o = Math.abs(o), R2[n2] = (R2[n2] || []).filter((g3) => !g3.isInFuture(r));
    let l2 = this.queryArc(r, r + a2).filter((g3) => g3.hasOnset());
    R2[n2] = R2[n2].concat(l2);
    let f4;
    const i = () => {
      const g3 = Wy(), u3 = g3 + a2;
      R2[n2] = R2[n2].filter((d2) => d2.isInNearPast(o, g3));
      let c3 = Math.max(f4 || u3, u3 - 1 / 10);
      const b2 = this.queryArc(c3, u3).filter((d2) => d2.hasOnset());
      R2[n2] = R2[n2].concat(b2), f4 = u3, t(R2[n2], g3, u3, this), $4[n2] = requestAnimationFrame(i);
    };
    return $4[n2] = requestAnimationFrame(i), this;
  };
  f2.prototype.onPaint = function(t) {
    return this.withState((e) => (e.controls.painters || (e.controls.painters = []), e.controls.painters.push(t), e));
  };
  f2.prototype.getPainters = function() {
    let t = [];
    return this.queryArc(0, 0, { painters: t }), t;
  };
  var ye4 = {
    background: "#222",
    foreground: "#75baff",
    caret: "#ffcc00",
    selection: "rgba(128, 203, 196, 0.5)",
    selectionMatch: "#036dd626",
    lineHighlight: "#00000050",
    gutterBackground: "transparent",
    gutterForeground: "#8a919966"
  };
  function W3() {
    return ye4;
  }
  var fe4 = "#22222210";
  f2.prototype.animate = function({ callback: t, sync: e = false, smear: n2 = 0.5 } = {}) {
    window.frame && cancelAnimationFrame(window.frame);
    const o = Z3();
    let { clientWidth: a2, clientHeight: r } = o.canvas;
    a2 *= window.devicePixelRatio, r *= window.devicePixelRatio;
    let l2 = n2 === 0 ? "99" : Number((1 - n2) * 100).toFixed(0);
    l2 = l2.length === 1 ? `0${l2}` : l2, fe4 = `#200010${l2}`;
    const f4 = (i) => {
      let g3;
      i = Math.round(i), g3 = this.slow(1e3).queryArc(i, i), o.fillStyle = fe4, o.fillRect(0, 0, a2, r), g3.forEach((u3) => {
        let { x: c3, y: b2, w: d2, h: w5, s: p2, r: k6, angle: h = 0, fill: S5 = "darkseagreen" } = u3.value;
        if (d2 *= a2, w5 *= r, k6 !== void 0 && h !== void 0) {
          const v2 = h * 2 * Math.PI, [y3, P3] = [(a2 - d2) / 2, (r - w5) / 2];
          c3 = y3 + Math.cos(v2) * k6 * y3, b2 = P3 + Math.sin(v2) * k6 * P3;
        } else
          c3 *= a2 - d2, b2 *= r - w5;
        const A4 = { ...u3.value, x: c3, y: b2, w: d2, h: w5 };
        o.fillStyle = S5, p2 === "rect" ? o.fillRect(c3, b2, d2, w5) : p2 === "ellipse" && (o.beginPath(), o.ellipse(c3 + d2 / 2, b2 + w5 / 2, d2 / 2, w5 / 2, 0, 0, 2 * Math.PI), o.fill()), t && t(o, A4, u3);
      }), window.frame = requestAnimationFrame(f4);
    };
    return window.frame = requestAnimationFrame(f4), q2;
  };
  var { x: we4, y: xe4, w: et4, h: tt3, angle: nt3, r: rt4, fill: at4, smear: ot4 } = Cp("x", "y", "w", "h", "angle", "r", "fill", "smear");
  var it4 = l("rescale", function(t, e) {
    return e.mul(we4(t).w(t).y(t).h(t));
  });
  var lt4 = l("moveXY", function(t, e, n2) {
    return n2.add(we4(t).y(e));
  });
  var st3 = l("zoomIn", function(t, e) {
    const n2 = C2(1).sub(t).div(2);
    return e.rescale(t).move(n2, n2);
  });
  var G2 = (t, e, n2) => t * (n2 - e) + e;
  var he3 = (t) => {
    let { value: e } = t;
    typeof t.value != "object" && (e = { value: e });
    let { note: n2, n: o, freq: a2, s: r } = e;
    if (a2)
      return Ze2(a2);
    if (n2 = n2 ?? o, typeof n2 == "string")
      try {
        return gt2(n2);
      } catch {
        return 0;
      }
    return typeof n2 == "number" ? n2 : r ? "_" + r : e;
  };
  f2.prototype.pianoroll = function(t = {}) {
    let { cycles: e = 4, playhead: n2 = 0.5, overscan: o = 0, hideNegative: a2 = false, ctx: r = Z3(), id: l2 = 1 } = t, f4 = -e * n2, i = e * (1 - n2);
    const g3 = (u3, c3) => (!a2 || u3.whole.begin >= 0) && u3.isWithinTime(c3 + f4, c3 + i);
    return this.draw(
      (u3, c3) => {
        ee3({
          ...t,
          time: c3,
          ctx: r,
          haps: u3.filter((b2) => g3(b2, c3))
        });
      },
      {
        lookbehind: f4 - o,
        lookahead: i + o,
        id: l2
      }
    ), this;
  };
  function ee3({
    time: t,
    haps: e,
    cycles: n2 = 4,
    playhead: o = 0.5,
    flipTime: a2 = 0,
    flipValues: r = 0,
    hideNegative: l2 = false,
    inactive: f4 = W3().foreground,
    active: i = W3().foreground,
    background: g3 = "transparent",
    smear: u3 = 0,
    playheadColor: c3 = W3().foreground,
    minMidi: b2 = 10,
    maxMidi: d2 = 90,
    autorange: w5 = 0,
    timeframe: p2,
    fold: k6 = 1,
    vertical: h = 0,
    labels: S5 = false,
    fill: A4 = 1,
    fillActive: v2 = false,
    strokeActive: y3 = true,
    stroke: P3,
    hideInactive: H5 = 0,
    colorizeInactive: q6 = 1,
    fontFamily: C6,
    ctx: s2,
    id: _5
  } = {}) {
    const T5 = s2.canvas.width, I3 = s2.canvas.height;
    let z4 = -n2 * o, j6 = n2 * (1 - o);
    _5 && (e = e.filter((m3) => m3.hasTag(_5))), p2 && (console.warn("timeframe is deprecated! use from/to instead"), z4 = 0, j6 = p2);
    const N5 = h ? I3 : T5, E4 = h ? T5 : I3;
    let L5 = h ? [N5, 0] : [0, N5];
    const J4 = j6 - z4, te4 = h ? [0, E4] : [E4, 0];
    let K4 = d2 - b2 + 1, D4 = E4 / K4, Q4 = [];
    a2 && L5.reverse(), r && te4.reverse();
    const { min: ke4, max: Pe3, values: Te5 } = e.reduce(
      ({ min: m3, max: F4, values: X }, Y4) => {
        const M2 = he3(Y4);
        return {
          min: M2 < m3 ? M2 : m3,
          max: M2 > F4 ? M2 : F4,
          values: X.includes(M2) ? X : [...X, M2]
        };
      },
      { min: 1 / 0, max: -1 / 0, values: [] }
    );
    w5 && (b2 = ke4, d2 = Pe3, K4 = d2 - b2 + 1), Q4 = Te5.sort(
      (m3, F4) => typeof m3 == "number" && typeof F4 == "number" ? m3 - F4 : typeof m3 == "number" ? 1 : String(m3).localeCompare(String(F4))
    ), D4 = k6 ? E4 / Q4.length : E4 / K4, s2.fillStyle = g3, s2.globalAlpha = 1, u3 || (s2.clearRect(0, 0, T5, I3), s2.fillRect(0, 0, T5, I3)), e.forEach((m3) => {
      const F4 = m3.whole.begin <= t && m3.endClipped > t;
      let X = P3 ?? (y3 && F4), Y4 = !F4 && A4 || F4 && v2;
      if (H5 && !F4)
        return;
      let M2 = m3.value?.color;
      i = M2 || i, f4 = q6 && M2 || f4, M2 = F4 ? i : f4, s2.fillStyle = Y4 ? M2 : "transparent", s2.strokeStyle = M2;
      const { velocity: Ae4 = 1, gain: qe4 = 1 } = m3.value || {};
      s2.globalAlpha = Ae4 * qe4;
      const Fe4 = (m3.whole.begin - (a2 ? j6 : z4)) / J4, ne4 = G2(Fe4, ...L5);
      let B5 = G2(m3.duration / J4, 0, N5);
      const re5 = he3(m3), Me5 = k6 ? Q4.indexOf(re5) / Q4.length : (Number(re5) - b2) / K4, ae3 = G2(Me5, ...te4);
      let oe3 = 0;
      const ie5 = G2(t / J4, ...L5);
      let V4;
      if (h ? V4 = [
        ae3 + 1 - (r ? D4 : 0),
        // x
        N5 - ie5 + ne4 + oe3 + 1 - (a2 ? 0 : B5),
        // y
        D4 - 2,
        // width
        B5 - 2
        // height
      ] : V4 = [
        ne4 - ie5 + oe3 + 1 - (a2 ? B5 : 0),
        // x
        ae3 + 1 - (r ? 0 : D4),
        // y
        B5 - 2,
        // widith
        D4 - 2
        // height
      ], X && s2.strokeRect(...V4), Y4 && s2.fillRect(...V4), S5) {
        const Se4 = m3.value.note ?? m3.value.s + (m3.value.n ? `:${m3.value.n}` : ""), { label: le3, activeLabel: Ce5 } = m3.value, He3 = (F4 && Ce5 || le3) ?? Se4;
        let Ie2 = h ? B5 : D4 * 0.75;
        s2.font = `${Ie2}px ${C6 || "monospace"}`, s2.fillStyle = /* isActive &&  */
        Y4 ? "black" : M2, s2.textBaseline = "top", s2.fillText(He3, ...V4);
      }
    }), s2.globalAlpha = 1;
    const U7 = G2(-z4 / J4, ...L5);
    return s2.strokeStyle = c3, s2.beginPath(), h ? (s2.moveTo(0, U7), s2.lineTo(E4, U7)) : (s2.moveTo(U7, 0), s2.lineTo(U7, E4)), s2.stroke(), this;
  }
  function ve3(t, e = {}) {
    let [n2, o] = t;
    n2 = Math.abs(n2);
    const a2 = o + n2, r = a2 !== 0 ? n2 / a2 : 0;
    return { fold: 1, ...e, cycles: a2, playhead: r };
  }
  var je4 = (t = {}) => (e, n2, o, a2) => ee3({ ctx: e, time: n2, haps: o, ...ve3(a2, t) });
  f2.prototype.punchcard = function(t) {
    return this.onPaint(je4(t));
  };
  f2.prototype.wordfall = function(t) {
    return this.punchcard({ vertical: 1, labels: 1, stroke: 0, fillActive: 1, active: "white", ...t });
  };
  function Xe4(t, e, n2, o) {
    const a2 = (t - 90) * Math.PI / 180;
    return [n2 + Math.cos(a2) * e, o + Math.sin(a2) * e];
  }
  var ue4 = (t, e, n2, o, a2 = 0) => Xe4((t + a2) * 360, e * t, n2, o);
  function me3(t) {
    let {
      ctx: e,
      from: n2 = 0,
      to: o = 3,
      margin: a2 = 50,
      cx: r = 100,
      cy: l2 = 100,
      rotate: f4 = 0,
      thickness: i = a2 / 2,
      color: g3 = W3().foreground,
      cap: u3 = "round",
      stretch: c3 = 1,
      fromOpacity: b2 = 1,
      toOpacity: d2 = 1
    } = t;
    n2 *= c3, o *= c3, f4 *= c3, e.lineWidth = i, e.lineCap = u3, e.strokeStyle = g3, e.globalAlpha = b2, e.beginPath();
    let [w5, p2] = ue4(n2, a2, r, l2, f4);
    e.moveTo(w5, p2);
    const k6 = 1 / 60;
    let h = n2;
    for (; h <= o; ) {
      const [S5, A4] = ue4(h, a2, r, l2, f4);
      e.globalAlpha = (h - n2) / (o - n2) * d2, e.lineTo(S5, A4), h += k6;
    }
    e.stroke();
  }
  function Ye3(t) {
    let {
      stretch: e = 1,
      size: n2 = 80,
      thickness: o = n2 / 2,
      cap: a2 = "butt",
      // round butt squar,
      inset: r = 3,
      // start angl,
      playheadColor: l2 = "#ffffff",
      playheadLength: f4 = 0.02,
      playheadThickness: i = o,
      padding: g3 = 0,
      steady: u3 = 1,
      activeColor: c3 = W3().foreground,
      inactiveColor: b2 = W3().gutterForeground,
      colorizeInactive: d2 = 0,
      fade: w5 = true,
      // logSpiral = true,
      ctx: p2,
      time: k6,
      haps: h,
      drawTime: S5,
      id: A4
    } = t;
    A4 && (h = h.filter((T5) => T5.hasTag(A4)));
    const [v2, y3] = [p2.canvas.width, p2.canvas.height];
    p2.clearRect(0, 0, v2 * 2, y3 * 2);
    const [P3, H5] = [v2 / 2, y3 / 2], q6 = {
      margin: n2 / e,
      cx: P3,
      cy: H5,
      stretch: e,
      cap: a2,
      thickness: o
    }, C6 = {
      ...q6,
      thickness: i,
      from: r - f4,
      to: r,
      color: l2
    }, [s2] = S5, _5 = u3 * k6;
    h.forEach((T5) => {
      const I3 = T5.whole.begin <= k6 && T5.endClipped > k6, z4 = T5.whole.begin - k6 + r, j6 = T5.endClipped - k6 + r - g3, N5 = T5.value?.color || c3, E4 = d2 || I3 ? N5 : b2, L5 = w5 ? 1 - Math.abs((T5.whole.begin - k6) / s2) : 1;
      me3({
        ctx: p2,
        ...q6,
        from: z4,
        to: j6,
        rotate: _5,
        color: E4,
        fromOpacity: L5,
        toOpacity: L5
      });
    }), me3({
      ctx: p2,
      ...C6,
      rotate: _5
    });
  }
  f2.prototype.spiral = function(t = {}) {
    return this.onPaint((e, n2, o, a2) => Ye3({ ctx: e, time: n2, haps: o, drawTime: a2, ...t }));
  };
  var Be4 = it2(36);
  var ge4 = (t, e, n2, o) => {
    o = o * Math.PI * 2;
    const a2 = Math.sin(o) * n2 + t, r = Math.cos(o) * n2 + e;
    return [a2, r];
  };
  var be3 = (t, e) => 0.5 - Math.log2(t / e) % 1;
  function Ve3({
    haps: t,
    ctx: e,
    id: n2,
    hapcircles: o = 1,
    circle: a2 = 0,
    edo: r = 12,
    root: l2 = Be4,
    thickness: f4 = 3,
    hapRadius: i = 6,
    mode: g3 = "flake",
    margin: u3 = 10
  } = {}) {
    const c3 = g3 === "polygon", b2 = g3 === "flake", d2 = e.canvas.width, w5 = e.canvas.height;
    e.clearRect(0, 0, d2, w5);
    const p2 = W3().foreground, h = Math.min(d2, w5) / 2 - f4 / 2 - i - u3, S5 = d2 / 2, A4 = w5 / 2;
    n2 && (t = t.filter((y3) => y3.hasTag(n2))), e.strokeStyle = p2, e.fillStyle = p2, e.globalAlpha = 1, e.lineWidth = f4, a2 && (e.beginPath(), e.arc(S5, A4, h, 0, 2 * Math.PI), e.stroke()), r && (Array.from({ length: r }, (y3, P3) => {
      const H5 = be3(l2 * Math.pow(2, P3 / r), l2), [q6, C6] = ge4(S5, A4, h, H5);
      e.beginPath(), e.arc(q6, C6, i, 0, 2 * Math.PI), e.fill();
    }), e.stroke());
    let v2 = [];
    e.lineWidth = i, t.forEach((y3) => {
      let P3;
      try {
        P3 = rh(y3);
      } catch {
        return;
      }
      const H5 = be3(P3, l2), [q6, C6] = ge4(S5, A4, h, H5), s2 = y3.value.color || p2;
      e.strokeStyle = s2, e.fillStyle = s2;
      const { velocity: _5 = 1, gain: T5 = 1 } = y3.value || {}, I3 = _5 * T5;
      e.globalAlpha = I3, v2.push([q6, C6, H5, s2, I3]), e.beginPath(), o && (e.moveTo(q6 + i, C6), e.arc(q6, C6, i, 0, 2 * Math.PI), e.fill()), b2 && (e.moveTo(S5, A4), e.lineTo(q6, C6)), e.stroke();
    }), e.strokeStyle = p2, e.globalAlpha = 1, c3 && v2.length && (v2 = v2.sort((y3, P3) => y3[2] - P3[2]), e.beginPath(), e.moveTo(v2[0][0], v2[0][1]), v2.forEach(([y3, P3, H5, q6, C6]) => {
      e.strokeStyle = q6, e.globalAlpha = C6, e.lineTo(y3, P3);
    }), e.lineTo(v2[0][0], v2[0][1]), e.stroke());
  }
  f2.prototype.pitchwheel = function(t = {}) {
    let { ctx: e = Z3(), id: n2 = 1 } = t;
    return this.tag(n2).onPaint(
      (o, a2, r) => Ve3({
        ...t,
        time: a2,
        ctx: e,
        haps: r.filter((l2) => l2.isActive(a2)),
        id: n2
      })
    );
  };

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/webaudio/dist/index.mjs
  var C3;
  function ie4() {
    const e = z2();
    C3 = q3(
      e,
      "dough-processor",
      {},
      {
        outputChannelCount: [2]
      }
    ), lc2(C3);
  }
  var A2 = /* @__PURE__ */ new Map();
  var E3 = /* @__PURE__ */ new Map();
  f2.prototype.supradough = function() {
    return this.onTrigger((e, t, n2, o) => {
      e.value._begin = o, e.value._duration = e.duration / n2, !C3 && ie4();
      const s2 = (e.value.bank ? e.value.bank + "_" : "") + e.value.s, a2 = e.value.n ?? 0, r = `${s2}:${a2}`;
      if (A2.has(s2) && (e.value.s = r), A2.has(s2) && !E3.has(r)) {
        const i = A2.get(s2), c3 = i[a2 % i.length];
        console.log(`load ${r} from ${c3}`);
        const h = ue5(c3);
        E3.set(r, h), h.then(
          ({ channels: u3, sampleRate: l2 }) => C3.port.postMessage({
            sample: r,
            channels: u3,
            sampleRate: l2
          })
        );
      }
      C3.port.postMessage({ spawn: e.value });
    }, 1);
  };
  function re4(e, t = "") {
    if (!e.startsWith("github:"))
      throw new Error('expected "github:" at the start of pseudoUrl');
    let [n2, o] = e.split("github:");
    return o = o.endsWith("/") ? o.slice(0, -1) : o, o.split("/").length === 2 && (o += "/main"), `https://raw.githubusercontent.com/${o}/${t}`;
  }
  async function ce4(e) {
    if (e.startsWith("github:") && (e = re4(e, "strudel.json")), e.startsWith("local:") && (e = "http://localhost:5432"), e.startsWith("shabda:")) {
      let [o, s2] = e.split("shabda:");
      e = `https://shabda.ndre.gr/${s2}.json?strudel=1`;
    }
    if (e.startsWith("shabda/speech")) {
      let [o, s2] = e.split("shabda/speech");
      s2 = s2.startsWith("/") ? s2.substring(1) : s2;
      let [a2, r] = s2.split(":"), i = "f", c3 = "en-GB";
      a2 && ([c3, i] = a2.split("/")), e = `https://shabda.ndre.gr/speech/${r}.json?gender=${i}&language=${c3}&strudel=1'`;
    }
    if (typeof fetch != "function")
      return;
    const t = e.split("/").slice(0, -1).join("/");
    if (typeof fetch > "u")
      return;
    const n2 = await fetch(e).then((o) => o.json()).catch((o) => {
      throw console.error(o), new Error(`error loading "${e}"`);
    });
    return [n2, n2._base || t];
  }
  async function ue5(e) {
    const t = await fetch(e).then((o) => o.arrayBuffer()).then((o) => z2().decodeAudioData(o));
    let n2 = [];
    for (let o = 0; o < t.numberOfChannels; o++)
      n2.push(t.getChannelData(o));
    return { channels: n2, sampleRate: t.sampleRate };
  }
  async function le2(e, t) {
    if (typeof e == "string") {
      const [n2, o] = await ce4(e);
      return le2(n2, o);
    }
    Object.entries(e).map(async ([n2, o]) => {
      n2 !== "_base" && (o = o.map((s2) => t + s2), A2.set(n2, o));
    });
  }
  var T3;
  var de3 = () => (T3 = new AudioContext(), T3);
  var he4 = () => T3 || de3();
  var fe5 = (e) => console.log(e);
  function ge5(e, t = "superdough") {
    console.error(e), B3(`[${t}] error: ${e.message}`);
  }
  var B3 = (...e) => fe5(...e);
  var j4 = (e, t, n2) => Math.min(Math.max(e, t), n2);
  function I(e) {
    const t = he4().createGain();
    return t.gain.value = e, t;
  }
  function R3(e, t, n2) {
    const o = I(n2);
    return e.connect(o), o.connect(t), o;
  }
  function pe5(e, t, n2, o) {
    const s2 = new AudioWorkletNode(e, t, o);
    return Object.entries(n2).forEach(([a2, r]) => {
      r !== void 0 && (s2.parameters.get(a2).value = r);
    }), s2;
  }
  function me4(e, t, n2, o) {
    const s2 = new ConstantSourceNode(e), a2 = I(0);
    return a2.connect(e.destination), s2.connect(a2), Te4(s2, () => {
      U4(a2), U4(s2), t();
    }), s2.start(n2), s2.stop(o), s2;
  }
  var q4 = (e) => e / (1 + e);
  var ve4 = (e, t) => (e % t + t) % t;
  var be4 = (e, t) => (1 + t) * e / (1 + t * Math.abs(e));
  var y2 = (e, t) => Math.tanh(e * (1 + t));
  var we5 = (e, t) => j4((1 + t) * e, -1, 1);
  var F3 = (e, t) => {
    let n2 = (1 + 0.5 * t) * e;
    const o = ve4(n2 + 1, 4);
    return 1 - Math.abs(o - 2);
  };
  var ye5 = (e, t) => Math.sin(Math.PI / 2 * F3(e, t));
  var Ce4 = (e, t) => {
    const n2 = q4(Math.log1p(t)), o = (e - n2 / 3 * e * e * e) / (1 - n2 / 3);
    return y2(o, t);
  };
  var L3 = (e, t, n2 = false) => {
    const o = 1 + 2 * t, a2 = 0.07 * q4(Math.log1p(t)), r = y2(e + a2, 2 * t), i = y2(n2 ? a2 : -e + a2, 2 * t), c3 = r - i, h = 1 / Math.cosh(o * a2), u3 = h * h, l2 = Math.max(1e-8, (n2 ? 1 : 2) * o * u3);
    return y2(c3 / l2, t);
  };
  var Ne3 = (e, t) => L3(e, t, true);
  var Ae3 = (e, t) => {
    const n2 = 10 * Math.log1p(t);
    let o = 1, s2 = e, a2, r = 0;
    for (let i = 1; i < 64; i++) {
      if (i < 2) {
        r += i == 0 ? o : s2;
        continue;
      }
      a2 = 2 * e * o - s2, s2 = o, o = a2, i % 2 === 0 && (r += Math.min(1.3 * n2 / i, 2) * a2);
    }
    return y2(r, n2 / 20);
  };
  var Me4 = {
    scurve: be4,
    soft: y2,
    hard: we5,
    cubic: Ce4,
    diode: L3,
    asym: Ne3,
    fold: F3,
    sinefold: ye5,
    chebyshev: Ae3
  };
  Object.freeze(Object.keys(Me4));
  var Te4 = (e, t) => {
    const n2 = t;
    e.onended = function() {
      n2(), this.onended = null;
    };
  };
  var U4 = (e) => {
    if (e != null) {
      if (!(e instanceof AudioNode))
        throw new Error("releaseAudioNode can only release an AudioNode");
      if (e.disconnect(), e instanceof AudioScheduledSourceNode) {
        e.onended && e.onended.name !== "cleanup" && B3(
          "[superdough] Deprecation warning: it seems your code path is setting 'node.onended = callback' instead of using the onceEnded helper"
        );
        try {
          e.stop();
        } catch {
          e.start(e.context.currentTime + 5), e.stop();
        }
      }
      e instanceof AudioWorkletNode && e.parameters.get("end")?.setValueAtTime(0, 0);
    }
  };
  var w3 = (e, t) => e !== void 0 && e !== t;
  var D2 = (e) => new GainNode(e, { gain: 1, channelCount: 2, channelCountMode: "explicit" });
  var Se3 = class {
    constructor(t) {
      __publicField(this, "reverbNode");
      __publicField(this, "delayNode");
      __publicField(this, "output");
      __publicField(this, "summingNode");
      __publicField(this, "djfNode");
      __publicField(this, "audioContext");
      this.audioContext = t, this.output = D2(t), this.summingNode = D2(t), this.summingNode.connect(this.output);
    }
    disconnect() {
      this.output.disconnect(), this.summingNode.disconnect(), this.delayNode?.disconnect(), this.reverbNode?.disconnect();
    }
    getDjf(t, n2 = 0) {
      return this.djfNode == null && (this.djfNode = pe5(this.audioContext, "djf-processor", { value: t }), this.summingNode.disconnect(), this.summingNode.connect(this.djfNode), this.djfNode.connect(this.output)), this.djfNode.parameters.get("value").setValueAtTime(t, n2), this.djfNode;
    }
    getDelay(t = 0, n2 = 0.5, o) {
      return n2 = j4(n2, 0, 0.98), this.delayNode == null && (this.delayNode = this.audioContext.createFeedbackDelay(1, t, n2), this.delayNode.connect(this.summingNode), this.delayNode.start?.(o)), this.delayNode.delayTime.value !== t && this.delayNode.delayTime.setValueAtTime(t, o), this.delayNode.feedback.value !== n2 && this.delayNode.feedback.setValueAtTime(n2, o), this.delayNode;
    }
    getReverb(t, n2, o, s2, a2, r, i) {
      return this.reverbNode == null && (this.reverbNode = this.audioContext.createReverb(t, n2, o, s2, a2, r, i), this.reverbNode.connect(this.summingNode)), (w3(t, this.reverbNode.duration) || w3(n2, this.reverbNode.fade) || w3(o, this.reverbNode.lp) || w3(s2, this.reverbNode.dim) || w3(r, this.reverbNode.irspeed) || w3(i, this.reverbNode.irbegin) || this.reverbNode.ir !== a2) && this.reverbNode.generate(t, n2, o, s2, a2, r, i), this.reverbNode;
    }
    sendReverb(t, n2) {
      return R3(t, this.reverbNode, n2);
    }
    sendDelay(t, n2) {
      return R3(t, this.delayNode, n2);
    }
    duck(t, n2 = 0, o = 0.1, s2 = 1) {
      const a2 = n2, r = Math.max(o, 2e-3), i = this.output.gain;
      me4(
        this.audioContext,
        () => {
          const c3 = this.audioContext.currentTime, h = i.value;
          i.cancelScheduledValues(c3), i.setValueAtTime(h, c3);
          const u3 = Math.max(t, c3), l2 = j4(1 - Math.sqrt(s2), 0.01, h);
          i.exponentialRampToValueAtTime(l2, u3 + a2), i.exponentialRampToValueAtTime(1, u3 + a2 + r);
        },
        0,
        t - 0.01
      );
    }
    connectToOutput(t) {
      t.connect(this.summingNode);
    }
  };
  var Oe3 = class {
    constructor(t) {
      __publicField(this, "channelMerger");
      __publicField(this, "destinationGain");
      __publicField(this, "connectToDestination", (t, n2 = [0, 1]) => {
        const o = new StereoPannerNode(this.audioContext);
        t.connect(o);
        const s2 = new ChannelSplitterNode(this.audioContext, {
          numberOfOutputs: o.channelCount
        });
        o.connect(s2), n2.forEach((a2, r) => {
          s2.connect(this.channelMerger, r % o.channelCount, a2 % this.audioContext.destination.channelCount);
        });
      });
      this.audioContext = t, this.initializeAudio();
    }
    initializeAudio() {
      const t = this.audioContext, n2 = t.destination.maxChannelCount;
      this.audioContext.destination.channelCount = n2, this.channelMerger = new ChannelMergerNode(t, { numberOfInputs: t.destination.channelCount }), this.destinationGain = new GainNode(t), this.channelMerger.connect(this.destinationGain), this.destinationGain.connect(t.destination);
    }
    reset() {
      this.disconnect(), this.initializeAudio();
    }
    disconnect() {
      this.channelMerger.disconnect(), this.destinationGain.disconnect(), this.destinationGain = null, this.channelMerger = null;
    }
  };
  var _e3 = class {
    constructor(t) {
      __publicField(this, "audioContext");
      __publicField(this, "output");
      __publicField(this, "nodes", {});
      __publicField(this, "buses", {});
      this.audioContext = t, this.output = new Oe3(t);
    }
    reset() {
      Object.values(this.nodes).forEach((t) => {
        t.disconnect();
      }), Object.values(this.buses).forEach((t) => {
        t.disconnect();
      }), this.nodes = {}, this.buses = {}, this.output.reset();
    }
    duck(t, n2, o = 0, s2 = 0.1, a2 = 1) {
      const r = [t].flat(), i = [o].flat(), c3 = [s2].flat(), h = [a2].flat();
      r.forEach((u3, l2) => {
        const f4 = this.nodes[u3];
        if (f4 == null) {
          ge5(new Error(`duck target orbit ${u3} does not exist`), "superdough");
          return;
        }
        const p2 = i[l2] ?? i[0], d2 = Math.max(c3[l2] ?? c3[0], 2e-3), g3 = h[l2] ?? h[0];
        f4.duck(n2, p2, d2, g3);
      });
    }
    getOrbit(t, n2) {
      return this.nodes[t] == null && (this.nodes[t] = new Se3(this.audioContext), this.output.connectToDestination(this.nodes[t].output, n2)), this.nodes[t];
    }
    getBus(t) {
      return this.buses[t] == null && (this.buses[t] = D2(this.audioContext)), this.buses[t];
    }
  };
  ac2(us2);
  var { Pattern: $e3, logger: k3, repl: je5 } = dist_exports;
  Bo2(k3);
  var K3 = (e) => (e.ensureObjectValue(), e.value);
  var De2 = (e, t, n2, o, s2) => No2(K3(e), s2, n2, o, e.whole?.begin.valueOf());
  async function qe3(e, t, n2, o, s2, a2, r, i = void 0) {
    let c3 = z2();
    await c3.close(), c3 = new OfflineAudioContext(2, (o - n2) / t * s2, s2), Uo2(c3), dc2(new _e3(c3)), await Ro2({
      maxPolyphony: a2,
      multiChannelOrbits: r
    }), k3("[webaudio] preloading");
    let h = e.queryArc(n2, o, { _cps: t }).sort((u3, l2) => u3.whole.begin.valueOf() - l2.whole.begin.valueOf());
    for (const u3 of h)
      if (u3.hasOnset())
        try {
          await No2(
            K3(u3),
            (u3.whole.begin.valueOf() - n2) / t,
            u3.duration / t,
            t,
            (u3.whole?.begin.valueOf() - n2) / t
          );
        } catch (l2) {
          ct3(l2, "webaudio");
        }
    return k3("[webaudio] start rendering"), c3.startRendering().then((u3) => {
      const l2 = ke3(u3), f4 = new Blob([l2], { type: "audio/wav" }), p2 = URL.createObjectURL(f4), d2 = document.createElement("a");
      d2.href = p2, i = i ? `${i}.wav` : `${(/* @__PURE__ */ new Date()).toISOString()}.wav`, d2.download = `${i}`, document.body.appendChild(d2), d2.click(), document.body.removeChild(d2), URL.revokeObjectURL(p2);
    }).finally(async () => {
      Uo2(null), dc2(null), rc2();
    });
  }
  function Fe3(e = {}) {
    const t = e.audioContext ?? z2();
    return Uo2(t), e = {
      getTime: () => t.currentTime,
      defaultOutput: De2,
      ...e
    }, je5(e);
  }
  $e3.prototype.dough = function() {
    return this.onTrigger(Gc2, 1);
  };
  function ke3(e, t) {
    t = t || {};
    var n2 = e.numberOfChannels, o = e.sampleRate, s2 = t.float32 ? 3 : 1, a2 = s2 === 3 ? 32 : 16, r;
    return n2 === 2 ? r = ze4(e.getChannelData(0), e.getChannelData(1)) : r = e.getChannelData(0), We2(r, s2, o, n2, a2);
  }
  function We2(e, t, n2, o, s2) {
    var a2 = s2 / 8, r = o * a2, i = new ArrayBuffer(44 + e.length * a2), c3 = new DataView(i);
    return N3(c3, 0, "RIFF"), c3.setUint32(4, 36 + e.length * a2, true), N3(c3, 8, "WAVE"), N3(c3, 12, "fmt "), c3.setUint32(16, 16, true), c3.setUint16(20, t, true), c3.setUint16(22, o, true), c3.setUint32(24, n2, true), c3.setUint32(28, n2 * r, true), c3.setUint16(32, r, true), c3.setUint16(34, s2, true), N3(c3, 36, "data"), c3.setUint32(40, e.length * a2, true), t === 1 ? Re2(c3, 44, e) : Ee3(c3, 44, e), i;
  }
  function ze4(e, t) {
    for (var n2 = e.length + t.length, o = new Float32Array(n2), s2 = 0, a2 = 0; s2 < n2; )
      o[s2++] = e[a2], o[s2++] = t[a2], a2++;
    return o;
  }
  function Ee3(e, t, n2) {
    for (var o = 0; o < n2.length; o++, t += 4)
      e.setFloat32(t, n2[o], true);
  }
  function Re2(e, t, n2) {
    for (var o = 0; o < n2.length; o++, t += 2) {
      var s2 = Math.max(-1, Math.min(1, n2[o]));
      e.setInt16(t, s2 < 0 ? s2 * 32768 : s2 * 32767, true);
    }
  }
  function N3(e, t, n2) {
    for (var o = 0; o < n2.length; o++)
      e.setUint8(t + o, n2.charCodeAt(o));
  }
  function Ue4(e, {
    align: t = true,
    color: n2 = "white",
    thickness: o = 3,
    scale: s2 = 0.25,
    pos: a2 = 0.75,
    trigger: r = 0,
    ctx: i = Z3(),
    id: c3 = 1
  } = {}) {
    i.lineWidth = o, i.strokeStyle = n2;
    let h = i.canvas;
    if (!e) {
      i.beginPath();
      let g3 = a2 * h.height;
      i.moveTo(0, g3), i.lineTo(h.width, g3), i.stroke();
      return;
    }
    const u3 = ic2("time", c3);
    i.beginPath();
    const l2 = e.frequencyBinCount;
    let f4 = t ? Array.from(u3).findIndex((g3, m3, b2) => m3 && b2[m3 - 1] > -r && g3 <= -r) : 0;
    f4 = Math.max(f4, 0);
    const p2 = h.width * 1 / l2;
    let d2 = 0;
    for (let g3 = f4; g3 < l2; g3++) {
      const m3 = u3[g3] + 1, b2 = (a2 - s2 * (m3 - 1)) * h.height;
      g3 === 0 ? i.moveTo(d2, b2) : i.lineTo(d2, b2), d2 += p2;
    }
    i.stroke();
  }
  function Ve4(e, { color: t = "white", scale: n2 = 0.25, pos: o = 0.75, lean: s2 = 0.5, min: a2 = -150, max: r = 0, ctx: i = Z3(), id: c3 = 1 } = {}) {
    if (!e) {
      i.beginPath();
      let d2 = o * u3.height;
      i.moveTo(0, d2), i.lineTo(u3.width, d2), i.stroke();
      return;
    }
    const h = ic2("frequency", c3), u3 = i.canvas;
    i.fillStyle = t;
    const l2 = e.frequencyBinCount, f4 = u3.width * 1 / l2;
    let p2 = 0;
    for (let d2 = 0; d2 < l2; d2++) {
      const m3 = an((h[d2] - a2) / (r - a2), 0, 1) * n2, b2 = m3 * u3.height, J4 = (o - m3 * s2) * u3.height;
      i.fillRect(p2, J4, Math.max(f4, 1), b2), p2 += f4;
    }
  }
  function H3(e = 0, t = "0,0,0", n2 = Z3()) {
    e ? (n2.fillStyle = `rgba(${t},${1 - e})`, n2.fillRect(0, 0, n2.canvas.width, n2.canvas.height)) : n2.clearRect(0, 0, n2.canvas.width, n2.canvas.height);
  }
  f2.prototype.fscope = function(e = {}) {
    let t = e.id ?? 1;
    return this.analyze(t).draw(
      () => {
        H3(e.smear, "0,0,0", e.ctx), ne3[t] && Ve4(ne3[t], e);
      },
      { id: t }
    );
  };
  f2.prototype.tscope = function(e = {}) {
    let t = e.id ?? 1;
    return this.analyze(t).draw(
      (n2) => {
        e.color = n2[0]?.value?.color || W3().foreground, e.color, H3(e.smear, "0,0,0", e.ctx), Ue4(ne3[t], e);
      },
      { id: t }
    );
  };
  f2.prototype.scope = f2.prototype.tscope;
  var V3 = {};
  f2.prototype.spectrum = function(e = {}) {
    let t = e.id ?? 1;
    return this.analyze(t).draw(
      (n2) => {
        e.color = n2[0]?.value?.color || V3[t] || W3().foreground, V3[t] = e.color, xe5(ne3[t], e);
      },
      { id: t }
    );
  };
  f2.prototype.scope = f2.prototype.tscope;
  var _3 = /* @__PURE__ */ new Map();
  function xe5(e, { thickness: t = 3, speed: n2 = 1, min: o = -80, max: s2 = 0, ctx: a2 = Z3(), id: r = 1, color: i } = {}) {
    if (a2.lineWidth = t, a2.strokeStyle = i, !e)
      return;
    const c3 = n2, h = ic2("frequency", r), u3 = a2.canvas;
    a2.fillStyle = i;
    const l2 = e.frequencyBinCount;
    let f4 = _3.get(r) || a2.getImageData(0, 0, u3.width, u3.height);
    _3.set(r, f4), a2.clearRect(0, 0, a2.canvas.width, a2.canvas.height), a2.putImageData(f4, -c3, 0);
    let p2 = u3.width - n2;
    for (let d2 = 0; d2 < l2; d2++) {
      const g3 = an((h[d2] - o) / (s2 - o), 0, 1);
      a2.globalAlpha = g3;
      const m3 = Math.log(d2 + 1) / Math.log(l2) * u3.height;
      a2.fillRect(p2, u3.height - m3, c3, 2);
    }
    _3.set(r, a2.getImageData(0, 0, u3.width, u3.height));
  }

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/mini/dist/index.mjs
  var dist_exports3 = {};
  __export(dist_exports3, {
    StartRules: () => Gr2,
    SyntaxError: () => uu2,
    getLeafLocation: () => ee4,
    getLeafLocations: () => Yr2,
    getLeaves: () => Xr2,
    h: () => Jr2,
    m: () => Hr2,
    mini: () => te3,
    mini2ast: () => Au2,
    miniAllStrings: () => Qr2,
    minify: () => Kr2,
    parse: () => Mr2,
    patternifyAST: () => nu2
  });
  function Or2(t, i) {
    function e() {
      this.constructor = t;
    }
    e.prototype = i.prototype, t.prototype = new e();
  }
  function uu2(t, i, e, f4) {
    var l2 = Error.call(this, t);
    return Object.setPrototypeOf && Object.setPrototypeOf(l2, uu2.prototype), l2.expected = i, l2.found = e, l2.location = f4, l2.name = "SyntaxError", l2;
  }
  Or2(uu2, Error);
  function Cu2(t, i, e) {
    return e = e || " ", t.length > i ? t : (i -= t.length, e += e.repeat(i), t + e.slice(0, i));
  }
  uu2.prototype.format = function(t) {
    var i = "Error: " + this.message;
    if (this.location) {
      var e = null, f4;
      for (f4 = 0; f4 < t.length; f4++)
        if (t[f4].source === this.location.source) {
          e = t[f4].text.split(/\r\n|\n|\r/g);
          break;
        }
      var l2 = this.location.start, a2 = this.location.source && typeof this.location.source.offset == "function" ? this.location.source.offset(l2) : l2, D4 = this.location.source + ":" + a2.line + ":" + a2.column;
      if (e) {
        var v2 = this.location.end, g3 = Cu2("", a2.line.toString().length, " "), c3 = e[l2.line - 1], F4 = l2.line === v2.line ? v2.column : c3.length + 1, p2 = F4 - l2.column || 1;
        i += `
 --> ` + D4 + `
` + g3 + ` |
` + a2.line + " | " + c3 + `
` + g3 + " | " + Cu2("", l2.column - 1, " ") + Cu2("", p2, "^");
      } else
        i += `
 at ` + D4;
    }
    return i;
  };
  uu2.buildMessage = function(t, i) {
    var e = {
      literal: function(c3) {
        return '"' + l2(c3.text) + '"';
      },
      class: function(c3) {
        var F4 = c3.parts.map(function(p2) {
          return Array.isArray(p2) ? a2(p2[0]) + "-" + a2(p2[1]) : a2(p2);
        });
        return "[" + (c3.inverted ? "^" : "") + F4.join("") + "]";
      },
      any: function() {
        return "any character";
      },
      end: function() {
        return "end of input";
      },
      other: function(c3) {
        return c3.description;
      }
    };
    function f4(c3) {
      return c3.charCodeAt(0).toString(16).toUpperCase();
    }
    function l2(c3) {
      return c3.replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\0/g, "\\0").replace(/\t/g, "\\t").replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/[\x00-\x0F]/g, function(F4) {
        return "\\x0" + f4(F4);
      }).replace(/[\x10-\x1F\x7F-\x9F]/g, function(F4) {
        return "\\x" + f4(F4);
      });
    }
    function a2(c3) {
      return c3.replace(/\\/g, "\\\\").replace(/\]/g, "\\]").replace(/\^/g, "\\^").replace(/-/g, "\\-").replace(/\0/g, "\\0").replace(/\t/g, "\\t").replace(/\n/g, "\\n").replace(/\r/g, "\\r").replace(/[\x00-\x0F]/g, function(F4) {
        return "\\x0" + f4(F4);
      }).replace(/[\x10-\x1F\x7F-\x9F]/g, function(F4) {
        return "\\x" + f4(F4);
      });
    }
    function D4(c3) {
      return e[c3.type](c3);
    }
    function v2(c3) {
      var F4 = c3.map(D4), p2, w5;
      if (F4.sort(), F4.length > 0) {
        for (p2 = 1, w5 = 1; p2 < F4.length; p2++)
          F4[p2 - 1] !== F4[p2] && (F4[w5] = F4[p2], w5++);
        F4.length = w5;
      }
      switch (F4.length) {
        case 1:
          return F4[0];
        case 2:
          return F4[0] + " or " + F4[1];
        default:
          return F4.slice(0, -1).join(", ") + ", or " + F4[F4.length - 1];
      }
    }
    function g3(c3) {
      return c3 ? '"' + l2(c3) + '"' : "end of input";
    }
    return "Expected " + v2(t) + " but " + g3(i) + " found.";
  };
  function Mr2(t, i) {
    i = i !== void 0 ? i : {};
    var e = {}, f4 = i.grammarSource, l2 = { start: Uu2 }, a2 = Uu2, D4 = ".", v2 = "-", g3 = "0", c3 = ",", F4 = "|", p2 = "[", w5 = "]", P3 = "{", R5 = "}", su2 = "%", iu2 = "<", re5 = ">", ne4 = "!", se3 = "(", ie5 = ")", fe6 = "/", oe3 = "*", ae3 = "?", le3 = ":", Eu2 = "..", ce5 = "^", vu2 = "struct", $u2 = "target", mu2 = "euclid", _u2 = "slow", yu2 = "rotL", wu2 = "rotR", bu2 = "fast", xu2 = "scale", Iu2 = "//", ku2 = "cat", Ae4 = "$", Nu2 = "setcps", Pu2 = "setbpm", qu2 = "hush", pe6 = /^[1-9]/, ge6 = /^[eE]/, Fe4 = /^[+\-]/, he5 = /^[0-9]/, ju2 = /^[ \n\r\t\xA0]/, Be5 = /^["']/, Ce5 = /^[#\--.0-9A-Z\^-_a-z~\xAA\xB5\xBA\xC0-\xD6\xD8-\xF6\xF8-\u02C1\u02C6-\u02D1\u02E0-\u02E4\u02EC\u02EE\u0370-\u0374\u0376-\u0377\u037A-\u037D\u037F\u0386\u0388-\u038A\u038C\u038E-\u03A1\u03A3-\u03F5\u03F7-\u0481\u048A-\u052F\u0531-\u0556\u0559\u0560-\u0588\u05D0-\u05EA\u05EF-\u05F2\u0620-\u064A\u066E-\u066F\u0671-\u06D3\u06D5\u06E5-\u06E6\u06EE-\u06EF\u06FA-\u06FC\u06FF\u0710\u0712-\u072F\u074D-\u07A5\u07B1\u07CA-\u07EA\u07F4-\u07F5\u07FA\u0800-\u0815\u081A\u0824\u0828\u0840-\u0858\u0860-\u086A\u08A0-\u08B4\u08B6-\u08BD\u0904-\u0939\u093D\u0950\u0958-\u0961\u0971-\u0980\u0985-\u098C\u098F-\u0990\u0993-\u09A8\u09AA-\u09B0\u09B2\u09B6-\u09B9\u09BD\u09CE\u09DC-\u09DD\u09DF-\u09E1\u09F0-\u09F1\u09FC\u0A05-\u0A0A\u0A0F-\u0A10\u0A13-\u0A28\u0A2A-\u0A30\u0A32-\u0A33\u0A35-\u0A36\u0A38-\u0A39\u0A59-\u0A5C\u0A5E\u0A72-\u0A74\u0A85-\u0A8D\u0A8F-\u0A91\u0A93-\u0AA8\u0AAA-\u0AB0\u0AB2-\u0AB3\u0AB5-\u0AB9\u0ABD\u0AD0\u0AE0-\u0AE1\u0AF9\u0B05-\u0B0C\u0B0F-\u0B10\u0B13-\u0B28\u0B2A-\u0B30\u0B32-\u0B33\u0B35-\u0B39\u0B3D\u0B5C-\u0B5D\u0B5F-\u0B61\u0B71\u0B83\u0B85-\u0B8A\u0B8E-\u0B90\u0B92-\u0B95\u0B99-\u0B9A\u0B9C\u0B9E-\u0B9F\u0BA3-\u0BA4\u0BA8-\u0BAA\u0BAE-\u0BB9\u0BD0\u0C05-\u0C0C\u0C0E-\u0C10\u0C12-\u0C28\u0C2A-\u0C39\u0C3D\u0C58-\u0C5A\u0C60-\u0C61\u0C80\u0C85-\u0C8C\u0C8E-\u0C90\u0C92-\u0CA8\u0CAA-\u0CB3\u0CB5-\u0CB9\u0CBD\u0CDE\u0CE0-\u0CE1\u0CF1-\u0CF2\u0D05-\u0D0C\u0D0E-\u0D10\u0D12-\u0D3A\u0D3D\u0D4E\u0D54-\u0D56\u0D5F-\u0D61\u0D7A-\u0D7F\u0D85-\u0D96\u0D9A-\u0DB1\u0DB3-\u0DBB\u0DBD\u0DC0-\u0DC6\u0E01-\u0E30\u0E32-\u0E33\u0E40-\u0E46\u0E81-\u0E82\u0E84\u0E87-\u0E88\u0E8A\u0E8D\u0E94-\u0E97\u0E99-\u0E9F\u0EA1-\u0EA3\u0EA5\u0EA7\u0EAA-\u0EAB\u0EAD-\u0EB0\u0EB2-\u0EB3\u0EBD\u0EC0-\u0EC4\u0EC6\u0EDC-\u0EDF\u0F00\u0F40-\u0F47\u0F49-\u0F6C\u0F88-\u0F8C\u1000-\u102A\u103F\u1050-\u1055\u105A-\u105D\u1061\u1065-\u1066\u106E-\u1070\u1075-\u1081\u108E\u10A0-\u10C5\u10C7\u10CD\u10D0-\u10FA\u10FC-\u1248\u124A-\u124D\u1250-\u1256\u1258\u125A-\u125D\u1260-\u1288\u128A-\u128D\u1290-\u12B0\u12B2-\u12B5\u12B8-\u12BE\u12C0\u12C2-\u12C5\u12C8-\u12D6\u12D8-\u1310\u1312-\u1315\u1318-\u135A\u1380-\u138F\u13A0-\u13F5\u13F8-\u13FD\u1401-\u166C\u166F-\u167F\u1681-\u169A\u16A0-\u16EA\u16EE-\u16F8\u1700-\u170C\u170E-\u1711\u1720-\u1731\u1740-\u1751\u1760-\u176C\u176E-\u1770\u1780-\u17B3\u17D7\u17DC\u1820-\u1878\u1880-\u1884\u1887-\u18A8\u18AA\u18B0-\u18F5\u1900-\u191E\u1950-\u196D\u1970-\u1974\u1980-\u19AB\u19B0-\u19C9\u1A00-\u1A16\u1A20-\u1A54\u1AA7\u1B05-\u1B33\u1B45-\u1B4B\u1B83-\u1BA0\u1BAE-\u1BAF\u1BBA-\u1BE5\u1C00-\u1C23\u1C4D-\u1C4F\u1C5A-\u1C7D\u1C80-\u1C88\u1C90-\u1CBA\u1CBD-\u1CBF\u1CE9-\u1CEC\u1CEE-\u1CF1\u1CF5-\u1CF6\u1D00-\u1DBF\u1E00-\u1F15\u1F18-\u1F1D\u1F20-\u1F45\u1F48-\u1F4D\u1F50-\u1F57\u1F59\u1F5B\u1F5D\u1F5F-\u1F7D\u1F80-\u1FB4\u1FB6-\u1FBC\u1FBE\u1FC2-\u1FC4\u1FC6-\u1FCC\u1FD0-\u1FD3\u1FD6-\u1FDB\u1FE0-\u1FEC\u1FF2-\u1FF4\u1FF6-\u1FFC\u2071\u207F\u2090-\u209C\u2102\u2107\u210A-\u2113\u2115\u2119-\u211D\u2124\u2126\u2128\u212A-\u212D\u212F-\u2139\u213C-\u213F\u2145-\u2149\u214E\u2160-\u2188\u2C00-\u2C2E\u2C30-\u2C5E\u2C60-\u2CE4\u2CEB-\u2CEE\u2CF2-\u2CF3\u2D00-\u2D25\u2D27\u2D2D\u2D30-\u2D67\u2D6F\u2D80-\u2D96\u2DA0-\u2DA6\u2DA8-\u2DAE\u2DB0-\u2DB6\u2DB8-\u2DBE\u2DC0-\u2DC6\u2DC8-\u2DCE\u2DD0-\u2DD6\u2DD8-\u2DDE\u2E2F\u3005-\u3007\u3021-\u3029\u3031-\u3035\u3038-\u303C\u3041-\u3096\u309D-\u309F\u30A1-\u30FA\u30FC-\u30FF\u3105-\u312F\u3131-\u318E\u31A0-\u31BA\u31F0-\u31FF\u3400-\u4DB5\u4E00-\u9FEF\uA000-\uA48C\uA4D0-\uA4FD\uA500-\uA60C\uA610-\uA61F\uA62A-\uA62B\uA640-\uA66E\uA67F-\uA69D\uA6A0-\uA6EF\uA717-\uA71F\uA722-\uA788\uA78B-\uA7B9\uA7F7-\uA801\uA803-\uA805\uA807-\uA80A\uA80C-\uA822\uA840-\uA873\uA882-\uA8B3\uA8F2-\uA8F7\uA8FB\uA8FD-\uA8FE\uA90A-\uA925\uA930-\uA946\uA960-\uA97C\uA984-\uA9B2\uA9CF\uA9E0-\uA9E4\uA9E6-\uA9EF\uA9FA-\uA9FE\uAA00-\uAA28\uAA40-\uAA42\uAA44-\uAA4B\uAA60-\uAA76\uAA7A\uAA7E-\uAAAF\uAAB1\uAAB5-\uAAB6\uAAB9-\uAABD\uAAC0\uAAC2\uAADB-\uAADD\uAAE0-\uAAEA\uAAF2-\uAAF4\uAB01-\uAB06\uAB09-\uAB0E\uAB11-\uAB16\uAB20-\uAB26\uAB28-\uAB2E\uAB30-\uAB5A\uAB5C-\uAB65\uAB70-\uABE2\uAC00-\uD7A3\uD7B0-\uD7C6\uD7CB-\uD7FB\uF900-\uFA6D\uFA70-\uFAD9\uFB00-\uFB06\uFB13-\uFB17\uFB1D\uFB1F-\uFB28\uFB2A-\uFB36\uFB38-\uFB3C\uFB3E\uFB40-\uFB41\uFB43-\uFB44\uFB46-\uFBB1\uFBD3-\uFD3D\uFD50-\uFD8F\uFD92-\uFDC7\uFDF0-\uFDFB\uFE70-\uFE74\uFE76-\uFEFC\uFF21-\uFF3A\uFF41-\uFF5A\uFF66-\uFFBE\uFFC2-\uFFC7\uFFCA-\uFFCF\uFFD2-\uFFD7\uFFDA-\uFFDC]/, De3 = /^[@_]/, Su2 = /^[^\n]/, de4 = pu2("number"), Ru2 = _5(".", false), Ee4 = O2([["1", "9"]], false, false), ve5 = O2(["e", "E"], false, false), $e4 = O2(["+", "-"], false, false), me5 = _5("-", false), _e4 = _5("0", false), ye6 = O2([["0", "9"]], false, false), we6 = pu2("whitespace"), Lu2 = O2([" ", `
`, "\r", "	", "\xA0"], false, false), be5 = _5(",", false), xe6 = _5("|", false), Ie2 = O2(['"', "'"], false, false), ke4 = pu2('a letter, a number, "-", "#", ".", "^", "_"'), Ne4 = O2(["#", ["-", "."], ["0", "9"], ["A", "Z"], ["^", "_"], ["a", "z"], "~", "\xAA", "\xB5", "\xBA", ["\xC0", "\xD6"], ["\xD8", "\xF6"], ["\xF8", "\u02C1"], ["\u02C6", "\u02D1"], ["\u02E0", "\u02E4"], "\u02EC", "\u02EE", ["\u0370", "\u0374"], ["\u0376", "\u0377"], ["\u037A", "\u037D"], "\u037F", "\u0386", ["\u0388", "\u038A"], "\u038C", ["\u038E", "\u03A1"], ["\u03A3", "\u03F5"], ["\u03F7", "\u0481"], ["\u048A", "\u052F"], ["\u0531", "\u0556"], "\u0559", ["\u0560", "\u0588"], ["\u05D0", "\u05EA"], ["\u05EF", "\u05F2"], ["\u0620", "\u064A"], ["\u066E", "\u066F"], ["\u0671", "\u06D3"], "\u06D5", ["\u06E5", "\u06E6"], ["\u06EE", "\u06EF"], ["\u06FA", "\u06FC"], "\u06FF", "\u0710", ["\u0712", "\u072F"], ["\u074D", "\u07A5"], "\u07B1", ["\u07CA", "\u07EA"], ["\u07F4", "\u07F5"], "\u07FA", ["\u0800", "\u0815"], "\u081A", "\u0824", "\u0828", ["\u0840", "\u0858"], ["\u0860", "\u086A"], ["\u08A0", "\u08B4"], ["\u08B6", "\u08BD"], ["\u0904", "\u0939"], "\u093D", "\u0950", ["\u0958", "\u0961"], ["\u0971", "\u0980"], ["\u0985", "\u098C"], ["\u098F", "\u0990"], ["\u0993", "\u09A8"], ["\u09AA", "\u09B0"], "\u09B2", ["\u09B6", "\u09B9"], "\u09BD", "\u09CE", ["\u09DC", "\u09DD"], ["\u09DF", "\u09E1"], ["\u09F0", "\u09F1"], "\u09FC", ["\u0A05", "\u0A0A"], ["\u0A0F", "\u0A10"], ["\u0A13", "\u0A28"], ["\u0A2A", "\u0A30"], ["\u0A32", "\u0A33"], ["\u0A35", "\u0A36"], ["\u0A38", "\u0A39"], ["\u0A59", "\u0A5C"], "\u0A5E", ["\u0A72", "\u0A74"], ["\u0A85", "\u0A8D"], ["\u0A8F", "\u0A91"], ["\u0A93", "\u0AA8"], ["\u0AAA", "\u0AB0"], ["\u0AB2", "\u0AB3"], ["\u0AB5", "\u0AB9"], "\u0ABD", "\u0AD0", ["\u0AE0", "\u0AE1"], "\u0AF9", ["\u0B05", "\u0B0C"], ["\u0B0F", "\u0B10"], ["\u0B13", "\u0B28"], ["\u0B2A", "\u0B30"], ["\u0B32", "\u0B33"], ["\u0B35", "\u0B39"], "\u0B3D", ["\u0B5C", "\u0B5D"], ["\u0B5F", "\u0B61"], "\u0B71", "\u0B83", ["\u0B85", "\u0B8A"], ["\u0B8E", "\u0B90"], ["\u0B92", "\u0B95"], ["\u0B99", "\u0B9A"], "\u0B9C", ["\u0B9E", "\u0B9F"], ["\u0BA3", "\u0BA4"], ["\u0BA8", "\u0BAA"], ["\u0BAE", "\u0BB9"], "\u0BD0", ["\u0C05", "\u0C0C"], ["\u0C0E", "\u0C10"], ["\u0C12", "\u0C28"], ["\u0C2A", "\u0C39"], "\u0C3D", ["\u0C58", "\u0C5A"], ["\u0C60", "\u0C61"], "\u0C80", ["\u0C85", "\u0C8C"], ["\u0C8E", "\u0C90"], ["\u0C92", "\u0CA8"], ["\u0CAA", "\u0CB3"], ["\u0CB5", "\u0CB9"], "\u0CBD", "\u0CDE", ["\u0CE0", "\u0CE1"], ["\u0CF1", "\u0CF2"], ["\u0D05", "\u0D0C"], ["\u0D0E", "\u0D10"], ["\u0D12", "\u0D3A"], "\u0D3D", "\u0D4E", ["\u0D54", "\u0D56"], ["\u0D5F", "\u0D61"], ["\u0D7A", "\u0D7F"], ["\u0D85", "\u0D96"], ["\u0D9A", "\u0DB1"], ["\u0DB3", "\u0DBB"], "\u0DBD", ["\u0DC0", "\u0DC6"], ["\u0E01", "\u0E30"], ["\u0E32", "\u0E33"], ["\u0E40", "\u0E46"], ["\u0E81", "\u0E82"], "\u0E84", ["\u0E87", "\u0E88"], "\u0E8A", "\u0E8D", ["\u0E94", "\u0E97"], ["\u0E99", "\u0E9F"], ["\u0EA1", "\u0EA3"], "\u0EA5", "\u0EA7", ["\u0EAA", "\u0EAB"], ["\u0EAD", "\u0EB0"], ["\u0EB2", "\u0EB3"], "\u0EBD", ["\u0EC0", "\u0EC4"], "\u0EC6", ["\u0EDC", "\u0EDF"], "\u0F00", ["\u0F40", "\u0F47"], ["\u0F49", "\u0F6C"], ["\u0F88", "\u0F8C"], ["\u1000", "\u102A"], "\u103F", ["\u1050", "\u1055"], ["\u105A", "\u105D"], "\u1061", ["\u1065", "\u1066"], ["\u106E", "\u1070"], ["\u1075", "\u1081"], "\u108E", ["\u10A0", "\u10C5"], "\u10C7", "\u10CD", ["\u10D0", "\u10FA"], ["\u10FC", "\u1248"], ["\u124A", "\u124D"], ["\u1250", "\u1256"], "\u1258", ["\u125A", "\u125D"], ["\u1260", "\u1288"], ["\u128A", "\u128D"], ["\u1290", "\u12B0"], ["\u12B2", "\u12B5"], ["\u12B8", "\u12BE"], "\u12C0", ["\u12C2", "\u12C5"], ["\u12C8", "\u12D6"], ["\u12D8", "\u1310"], ["\u1312", "\u1315"], ["\u1318", "\u135A"], ["\u1380", "\u138F"], ["\u13A0", "\u13F5"], ["\u13F8", "\u13FD"], ["\u1401", "\u166C"], ["\u166F", "\u167F"], ["\u1681", "\u169A"], ["\u16A0", "\u16EA"], ["\u16EE", "\u16F8"], ["\u1700", "\u170C"], ["\u170E", "\u1711"], ["\u1720", "\u1731"], ["\u1740", "\u1751"], ["\u1760", "\u176C"], ["\u176E", "\u1770"], ["\u1780", "\u17B3"], "\u17D7", "\u17DC", ["\u1820", "\u1878"], ["\u1880", "\u1884"], ["\u1887", "\u18A8"], "\u18AA", ["\u18B0", "\u18F5"], ["\u1900", "\u191E"], ["\u1950", "\u196D"], ["\u1970", "\u1974"], ["\u1980", "\u19AB"], ["\u19B0", "\u19C9"], ["\u1A00", "\u1A16"], ["\u1A20", "\u1A54"], "\u1AA7", ["\u1B05", "\u1B33"], ["\u1B45", "\u1B4B"], ["\u1B83", "\u1BA0"], ["\u1BAE", "\u1BAF"], ["\u1BBA", "\u1BE5"], ["\u1C00", "\u1C23"], ["\u1C4D", "\u1C4F"], ["\u1C5A", "\u1C7D"], ["\u1C80", "\u1C88"], ["\u1C90", "\u1CBA"], ["\u1CBD", "\u1CBF"], ["\u1CE9", "\u1CEC"], ["\u1CEE", "\u1CF1"], ["\u1CF5", "\u1CF6"], ["\u1D00", "\u1DBF"], ["\u1E00", "\u1F15"], ["\u1F18", "\u1F1D"], ["\u1F20", "\u1F45"], ["\u1F48", "\u1F4D"], ["\u1F50", "\u1F57"], "\u1F59", "\u1F5B", "\u1F5D", ["\u1F5F", "\u1F7D"], ["\u1F80", "\u1FB4"], ["\u1FB6", "\u1FBC"], "\u1FBE", ["\u1FC2", "\u1FC4"], ["\u1FC6", "\u1FCC"], ["\u1FD0", "\u1FD3"], ["\u1FD6", "\u1FDB"], ["\u1FE0", "\u1FEC"], ["\u1FF2", "\u1FF4"], ["\u1FF6", "\u1FFC"], "\u2071", "\u207F", ["\u2090", "\u209C"], "\u2102", "\u2107", ["\u210A", "\u2113"], "\u2115", ["\u2119", "\u211D"], "\u2124", "\u2126", "\u2128", ["\u212A", "\u212D"], ["\u212F", "\u2139"], ["\u213C", "\u213F"], ["\u2145", "\u2149"], "\u214E", ["\u2160", "\u2188"], ["\u2C00", "\u2C2E"], ["\u2C30", "\u2C5E"], ["\u2C60", "\u2CE4"], ["\u2CEB", "\u2CEE"], ["\u2CF2", "\u2CF3"], ["\u2D00", "\u2D25"], "\u2D27", "\u2D2D", ["\u2D30", "\u2D67"], "\u2D6F", ["\u2D80", "\u2D96"], ["\u2DA0", "\u2DA6"], ["\u2DA8", "\u2DAE"], ["\u2DB0", "\u2DB6"], ["\u2DB8", "\u2DBE"], ["\u2DC0", "\u2DC6"], ["\u2DC8", "\u2DCE"], ["\u2DD0", "\u2DD6"], ["\u2DD8", "\u2DDE"], "\u2E2F", ["\u3005", "\u3007"], ["\u3021", "\u3029"], ["\u3031", "\u3035"], ["\u3038", "\u303C"], ["\u3041", "\u3096"], ["\u309D", "\u309F"], ["\u30A1", "\u30FA"], ["\u30FC", "\u30FF"], ["\u3105", "\u312F"], ["\u3131", "\u318E"], ["\u31A0", "\u31BA"], ["\u31F0", "\u31FF"], ["\u3400", "\u4DB5"], ["\u4E00", "\u9FEF"], ["\uA000", "\uA48C"], ["\uA4D0", "\uA4FD"], ["\uA500", "\uA60C"], ["\uA610", "\uA61F"], ["\uA62A", "\uA62B"], ["\uA640", "\uA66E"], ["\uA67F", "\uA69D"], ["\uA6A0", "\uA6EF"], ["\uA717", "\uA71F"], ["\uA722", "\uA788"], ["\uA78B", "\uA7B9"], ["\uA7F7", "\uA801"], ["\uA803", "\uA805"], ["\uA807", "\uA80A"], ["\uA80C", "\uA822"], ["\uA840", "\uA873"], ["\uA882", "\uA8B3"], ["\uA8F2", "\uA8F7"], "\uA8FB", ["\uA8FD", "\uA8FE"], ["\uA90A", "\uA925"], ["\uA930", "\uA946"], ["\uA960", "\uA97C"], ["\uA984", "\uA9B2"], "\uA9CF", ["\uA9E0", "\uA9E4"], ["\uA9E6", "\uA9EF"], ["\uA9FA", "\uA9FE"], ["\uAA00", "\uAA28"], ["\uAA40", "\uAA42"], ["\uAA44", "\uAA4B"], ["\uAA60", "\uAA76"], "\uAA7A", ["\uAA7E", "\uAAAF"], "\uAAB1", ["\uAAB5", "\uAAB6"], ["\uAAB9", "\uAABD"], "\uAAC0", "\uAAC2", ["\uAADB", "\uAADD"], ["\uAAE0", "\uAAEA"], ["\uAAF2", "\uAAF4"], ["\uAB01", "\uAB06"], ["\uAB09", "\uAB0E"], ["\uAB11", "\uAB16"], ["\uAB20", "\uAB26"], ["\uAB28", "\uAB2E"], ["\uAB30", "\uAB5A"], ["\uAB5C", "\uAB65"], ["\uAB70", "\uABE2"], ["\uAC00", "\uD7A3"], ["\uD7B0", "\uD7C6"], ["\uD7CB", "\uD7FB"], ["\uF900", "\uFA6D"], ["\uFA70", "\uFAD9"], ["\uFB00", "\uFB06"], ["\uFB13", "\uFB17"], "\uFB1D", ["\uFB1F", "\uFB28"], ["\uFB2A", "\uFB36"], ["\uFB38", "\uFB3C"], "\uFB3E", ["\uFB40", "\uFB41"], ["\uFB43", "\uFB44"], ["\uFB46", "\uFBB1"], ["\uFBD3", "\uFD3D"], ["\uFD50", "\uFD8F"], ["\uFD92", "\uFDC7"], ["\uFDF0", "\uFDFB"], ["\uFE70", "\uFE74"], ["\uFE76", "\uFEFC"], ["\uFF21", "\uFF3A"], ["\uFF41", "\uFF5A"], ["\uFF66", "\uFFBE"], ["\uFFC2", "\uFFC7"], ["\uFFCA", "\uFFCF"], ["\uFFD2", "\uFFD7"], ["\uFFDA", "\uFFDC"]], false, false), Ou2 = _5("[", false), Mu2 = _5("]", false), Pe3 = _5("{", false), qe4 = _5("}", false), je6 = _5("%", false), Se4 = _5("<", false), Re3 = _5(">", false), Le3 = O2(["@", "_"], false, false), Oe4 = _5("!", false), Me5 = _5("(", false), ze5 = _5(")", false), Te5 = _5("/", false), Ze3 = _5("*", false), We3 = _5("?", false), Ue5 = _5(":", false), Ve5 = _5("..", false), Xe5 = _5("^", false), Ge2 = _5("struct", false), Ye4 = _5("target", false), He3 = _5("euclid", false), Je3 = _5("slow", false), Ke3 = _5("rotL", false), Qe3 = _5("rotR", false), ut4 = _5("fast", false), et5 = _5("scale", false), tt4 = _5("//", false), zu2 = O2([`
`], true, false), rt5 = _5("cat", false), nt4 = _5("$", false), st4 = _5("setcps", false), it5 = _5("setbpm", false), ft2 = _5("hush", false), ot5 = function() {
      return parseFloat(Xt4());
    }, at5 = function(u3) {
      const r = u3.join("");
      return r === "." || r === "_";
    }, lt5 = function(u3) {
      return new Sr2(u3.join(""));
    }, ct4 = function(u3) {
      return u3;
    }, At3 = function(u3, r) {
      return u3.arguments_.stepsPerCycle = r, u3;
    }, pt4 = function(u3) {
      return u3;
    }, gt4 = function(u3) {
      return u3.arguments_.alignment = "polymeter_slowcat", u3;
    }, Ft4 = function(u3) {
      return (r) => r.options_.weight = (r.options_.weight ?? 1) + (u3 ?? 2) - 1;
    }, ht3 = function(u3) {
      return (r) => {
        const s2 = (r.options_.reps ?? 1) + (u3 ?? 2) - 1;
        r.options_.reps = s2, r.options_.ops = r.options_.ops.filter((o) => o.type_ !== "replicate"), r.options_.ops.push({ type_: "replicate", arguments_: { amount: s2 } }), r.options_.weight = s2;
      };
    }, Bt4 = function(u3, r, s2) {
      return (o) => o.options_.ops.push({ type_: "bjorklund", arguments_: { pulse: u3, step: r, rotation: s2 } });
    }, Ct4 = function(u3) {
      return (r) => r.options_.ops.push({ type_: "stretch", arguments_: { amount: u3, type: "slow" } });
    }, Dt3 = function(u3) {
      return (r) => r.options_.ops.push({ type_: "stretch", arguments_: { amount: u3, type: "fast" } });
    }, dt4 = function(u3) {
      return (r) => r.options_.ops.push({ type_: "degradeBy", arguments_: { amount: u3, seed: Bu2++ } });
    }, Et4 = function(u3) {
      return (r) => r.options_.ops.push({ type_: "tail", arguments_: { element: u3 } });
    }, vt4 = function(u3) {
      return (r) => r.options_.ops.push({ type_: "range", arguments_: { element: u3 } });
    }, $t4 = function(u3, r) {
      const s2 = new Lr2(u3, { ops: [], weight: 1, reps: 1 });
      for (const o of r)
        o(s2);
      return s2;
    }, mt4 = function(u3, r) {
      return new lu2(r, "fastcat", void 0, !!u3);
    }, _t4 = function(u3) {
      return { alignment: "stack", list: u3 };
    }, yt4 = function(u3) {
      return { alignment: "rand", list: u3, seed: Bu2++ };
    }, wt4 = function(u3) {
      return { alignment: "feet", list: u3, seed: Bu2++ };
    }, bt4 = function(u3, r) {
      return r && r.list.length > 0 ? new lu2([u3, ...r.list], r.alignment, r.seed) : u3;
    }, xt4 = function(u3, r) {
      return new lu2(r ? [u3, ...r.list] : [u3], "polymeter");
    }, It4 = function(u3) {
      return u3;
    }, kt4 = function(u3) {
      return { name: "struct", args: { mini: u3 } };
    }, Nt4 = function(u3) {
      return { name: "target", args: { name: u3 } };
    }, Pt4 = function(u3, r, s2) {
      return { name: "bjorklund", args: { pulse: u3, step: parseInt(r) } };
    }, qt4 = function(u3) {
      return { name: "stretch", args: { amount: u3 } };
    }, jt4 = function(u3) {
      return { name: "shift", args: { amount: "-" + u3 } };
    }, St3 = function(u3) {
      return { name: "shift", args: { amount: u3 } };
    }, Rt4 = function(u3) {
      return { name: "stretch", args: { amount: "1/" + u3 } };
    }, Lt4 = function(u3) {
      return { name: "scale", args: { scale: u3.join("") } };
    }, Tu2 = function(u3, r) {
      return r;
    }, Ot4 = function(u3, r) {
      return r.unshift(u3), new lu2(r, "slowcat");
    }, Mt3 = function(u3) {
      return u3;
    }, zt4 = function(u3, r) {
      return new Rr2(u3.name, u3.args, r);
    }, Tt3 = function(u3) {
      return u3;
    }, Zt4 = function(u3) {
      return u3;
    }, Wt3 = function(u3) {
      return new hu2("setcps", { value: u3 });
    }, Ut4 = function(u3) {
      return new hu2("setcps", { value: u3 / 120 / 2 });
    }, Vt3 = function() {
      return new hu2("hush");
    }, n2 = i.peg$currPos | 0, $5 = n2, V4 = [{ line: 1, column: 1 }], q6 = n2, fu2 = i.peg$maxFailExpected || [], h = i.peg$silentFails | 0, eu2;
    if (i.startRule) {
      if (!(i.startRule in l2))
        throw new Error(`Can't start parsing from rule "` + i.startRule + '".');
      a2 = l2[i.startRule];
    }
    function Xt4() {
      return t.substring($5, n2);
    }
    function Zu2() {
      return gu2($5, n2);
    }
    function _5(u3, r) {
      return { type: "literal", text: u3, ignoreCase: r };
    }
    function O2(u3, r, s2) {
      return { type: "class", parts: u3, inverted: r, ignoreCase: s2 };
    }
    function Gt3() {
      return { type: "end" };
    }
    function pu2(u3) {
      return { type: "other", description: u3 };
    }
    function Wu2(u3) {
      var r = V4[u3], s2;
      if (r)
        return r;
      if (u3 >= V4.length)
        s2 = V4.length - 1;
      else
        for (s2 = u3; !V4[--s2]; )
          ;
      for (r = V4[s2], r = {
        line: r.line,
        column: r.column
      }; s2 < u3; )
        t.charCodeAt(s2) === 10 ? (r.line++, r.column = 1) : r.column++, s2++;
      return V4[u3] = r, r;
    }
    function gu2(u3, r, s2) {
      var o = Wu2(u3), B5 = Wu2(r), x2 = {
        source: f4,
        start: {
          offset: u3,
          line: o.line,
          column: o.column
        },
        end: {
          offset: r,
          line: B5.line,
          column: B5.column
        }
      };
      return x2;
    }
    function d2(u3) {
      n2 < q6 || (n2 > q6 && (q6 = n2, fu2 = []), fu2.push(u3));
    }
    function Yt4(u3, r, s2) {
      return new uu2(
        uu2.buildMessage(u3, r),
        u3,
        r,
        s2
      );
    }
    function Uu2() {
      var u3;
      return u3 = jr2(), u3;
    }
    function M2() {
      var u3, r;
      return h++, u3 = n2, er2(), r = ou2(), r !== e ? (ur2(), Qt3(), $5 = u3, u3 = ot5()) : (n2 = u3, u3 = e), h--, u3 === e && h === 0 && d2(de4), u3;
    }
    function Ht3() {
      var u3;
      return t.charCodeAt(n2) === 46 ? (u3 = D4, n2++) : (u3 = e, h === 0 && d2(Ru2)), u3;
    }
    function Jt4() {
      var u3;
      return u3 = t.charAt(n2), pe6.test(u3) ? n2++ : (u3 = e, h === 0 && d2(Ee4)), u3;
    }
    function Kt4() {
      var u3;
      return u3 = t.charAt(n2), ge6.test(u3) ? n2++ : (u3 = e, h === 0 && d2(ve5)), u3;
    }
    function Qt3() {
      var u3, r, s2, o, B5;
      if (u3 = n2, r = Kt4(), r !== e) {
        if (s2 = t.charAt(n2), Fe4.test(s2) ? n2++ : (s2 = e, h === 0 && d2($e4)), s2 === e && (s2 = null), o = [], B5 = X(), B5 !== e)
          for (; B5 !== e; )
            o.push(B5), B5 = X();
        else
          o = e;
        o !== e ? (r = [r, s2, o], u3 = r) : (n2 = u3, u3 = e);
      } else
        n2 = u3, u3 = e;
      return u3;
    }
    function ur2() {
      var u3, r, s2, o;
      if (u3 = n2, r = Ht3(), r !== e) {
        if (s2 = [], o = X(), o !== e)
          for (; o !== e; )
            s2.push(o), o = X();
        else
          s2 = e;
        s2 !== e ? (r = [r, s2], u3 = r) : (n2 = u3, u3 = e);
      } else
        n2 = u3, u3 = e;
      return u3;
    }
    function ou2() {
      var u3, r, s2, o;
      if (u3 = tr2(), u3 === e)
        if (u3 = n2, r = Jt4(), r !== e) {
          for (s2 = [], o = X(); o !== e; )
            s2.push(o), o = X();
          r = [r, s2], u3 = r;
        } else
          n2 = u3, u3 = e;
      return u3;
    }
    function er2() {
      var u3;
      return t.charCodeAt(n2) === 45 ? (u3 = v2, n2++) : (u3 = e, h === 0 && d2(me5)), u3;
    }
    function tr2() {
      var u3;
      return t.charCodeAt(n2) === 48 ? (u3 = g3, n2++) : (u3 = e, h === 0 && d2(_e4)), u3;
    }
    function X() {
      var u3;
      return u3 = t.charAt(n2), he5.test(u3) ? n2++ : (u3 = e, h === 0 && d2(ye6)), u3;
    }
    function E4() {
      var u3, r;
      for (h++, u3 = [], r = t.charAt(n2), ju2.test(r) ? n2++ : (r = e, h === 0 && d2(Lu2)); r !== e; )
        u3.push(r), r = t.charAt(n2), ju2.test(r) ? n2++ : (r = e, h === 0 && d2(Lu2));
      return h--, r = e, h === 0 && d2(we6), u3;
    }
    function G4() {
      var u3, r, s2, o;
      return u3 = n2, r = E4(), t.charCodeAt(n2) === 44 ? (s2 = c3, n2++) : (s2 = e, h === 0 && d2(be5)), s2 !== e ? (o = E4(), r = [r, s2, o], u3 = r) : (n2 = u3, u3 = e), u3;
    }
    function Vu2() {
      var u3, r, s2, o;
      return u3 = n2, r = E4(), t.charCodeAt(n2) === 124 ? (s2 = F4, n2++) : (s2 = e, h === 0 && d2(xe6)), s2 !== e ? (o = E4(), r = [r, s2, o], u3 = r) : (n2 = u3, u3 = e), u3;
    }
    function Xu2() {
      var u3, r, s2, o;
      return u3 = n2, r = E4(), t.charCodeAt(n2) === 46 ? (s2 = D4, n2++) : (s2 = e, h === 0 && d2(Ru2)), s2 !== e ? (o = E4(), r = [r, s2, o], u3 = r) : (n2 = u3, u3 = e), u3;
    }
    function Y4() {
      var u3;
      return u3 = t.charAt(n2), Be5.test(u3) ? n2++ : (u3 = e, h === 0 && d2(Ie2)), u3;
    }
    function au2() {
      var u3;
      return h++, u3 = t.charAt(n2), Ce5.test(u3) ? n2++ : (u3 = e, h === 0 && d2(Ne4)), h--, u3 === e && h === 0 && d2(ke4), u3;
    }
    function Gu2() {
      var u3, r, s2, o;
      if (u3 = n2, E4(), r = [], s2 = au2(), s2 !== e)
        for (; s2 !== e; )
          r.push(s2), s2 = au2();
      else
        r = e;
      return r !== e ? (s2 = E4(), $5 = n2, o = at5(r), o ? o = e : o = void 0, o !== e ? ($5 = u3, u3 = lt5(r)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function rr2() {
      var u3, r, s2, o;
      return u3 = n2, E4(), t.charCodeAt(n2) === 91 ? (r = p2, n2++) : (r = e, h === 0 && d2(Ou2)), r !== e ? (E4(), s2 = Ju2(), s2 !== e ? (E4(), t.charCodeAt(n2) === 93 ? (o = w5, n2++) : (o = e, h === 0 && d2(Mu2)), o !== e ? (E4(), $5 = u3, u3 = ct4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function nr2() {
      var u3, r, s2, o, B5;
      return u3 = n2, E4(), t.charCodeAt(n2) === 123 ? (r = P3, n2++) : (r = e, h === 0 && d2(Pe3)), r !== e ? (E4(), s2 = Ku2(), s2 !== e ? (E4(), t.charCodeAt(n2) === 125 ? (o = R5, n2++) : (o = e, h === 0 && d2(qe4)), o !== e ? (B5 = sr2(), B5 === e && (B5 = null), E4(), $5 = u3, u3 = At3(s2, B5)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function sr2() {
      var u3, r, s2;
      return u3 = n2, t.charCodeAt(n2) === 37 ? (r = su2, n2++) : (r = e, h === 0 && d2(je6)), r !== e ? (s2 = H5(), s2 !== e ? ($5 = u3, u3 = pt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function ir2() {
      var u3, r, s2, o;
      return u3 = n2, E4(), t.charCodeAt(n2) === 60 ? (r = iu2, n2++) : (r = e, h === 0 && d2(Se4)), r !== e ? (E4(), s2 = Ku2(), s2 !== e ? (E4(), t.charCodeAt(n2) === 62 ? (o = re5, n2++) : (o = e, h === 0 && d2(Re3)), o !== e ? (E4(), $5 = u3, u3 = gt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function H5() {
      var u3;
      return u3 = Gu2(), u3 === e && (u3 = rr2(), u3 === e && (u3 = nr2(), u3 === e && (u3 = ir2()))), u3;
    }
    function Yu2() {
      var u3;
      return u3 = fr2(), u3 === e && (u3 = ar2(), u3 === e && (u3 = lr2(), u3 === e && (u3 = cr2(), u3 === e && (u3 = or2(), u3 === e && (u3 = Ar2(), u3 === e && (u3 = pr2(), u3 === e && (u3 = gr2()))))))), u3;
    }
    function fr2() {
      var u3, r, s2;
      return u3 = n2, E4(), r = t.charAt(n2), De3.test(r) ? n2++ : (r = e, h === 0 && d2(Le3)), r !== e ? (s2 = M2(), s2 === e && (s2 = null), $5 = u3, u3 = Ft4(s2)) : (n2 = u3, u3 = e), u3;
    }
    function or2() {
      var u3, r, s2;
      return u3 = n2, E4(), t.charCodeAt(n2) === 33 ? (r = ne4, n2++) : (r = e, h === 0 && d2(Oe4)), r !== e ? (s2 = M2(), s2 === e && (s2 = null), $5 = u3, u3 = ht3(s2)) : (n2 = u3, u3 = e), u3;
    }
    function ar2() {
      var u3, r, s2, o, B5, x2, j6;
      return u3 = n2, t.charCodeAt(n2) === 40 ? (r = se3, n2++) : (r = e, h === 0 && d2(Me5)), r !== e ? (E4(), s2 = tu2(), s2 !== e ? (E4(), o = G4(), o !== e ? (E4(), B5 = tu2(), B5 !== e ? (E4(), G4(), E4(), x2 = tu2(), x2 === e && (x2 = null), E4(), t.charCodeAt(n2) === 41 ? (j6 = ie5, n2++) : (j6 = e, h === 0 && d2(ze5)), j6 !== e ? ($5 = u3, u3 = Bt4(s2, B5, x2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function lr2() {
      var u3, r, s2;
      return u3 = n2, t.charCodeAt(n2) === 47 ? (r = fe6, n2++) : (r = e, h === 0 && d2(Te5)), r !== e ? (s2 = H5(), s2 !== e ? ($5 = u3, u3 = Ct4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function cr2() {
      var u3, r, s2;
      return u3 = n2, t.charCodeAt(n2) === 42 ? (r = oe3, n2++) : (r = e, h === 0 && d2(Ze3)), r !== e ? (s2 = H5(), s2 !== e ? ($5 = u3, u3 = Dt3(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function Ar2() {
      var u3, r, s2;
      return u3 = n2, t.charCodeAt(n2) === 63 ? (r = ae3, n2++) : (r = e, h === 0 && d2(We3)), r !== e ? (s2 = M2(), s2 === e && (s2 = null), $5 = u3, u3 = dt4(s2)) : (n2 = u3, u3 = e), u3;
    }
    function pr2() {
      var u3, r, s2;
      return u3 = n2, t.charCodeAt(n2) === 58 ? (r = le3, n2++) : (r = e, h === 0 && d2(Ue5)), r !== e ? (s2 = H5(), s2 !== e ? ($5 = u3, u3 = Et4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function gr2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 2) === Eu2 ? (r = Eu2, n2 += 2) : (r = e, h === 0 && d2(Ve5)), r !== e ? (s2 = H5(), s2 !== e ? ($5 = u3, u3 = vt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function tu2() {
      var u3, r, s2, o;
      if (u3 = n2, r = H5(), r !== e) {
        for (s2 = [], o = Yu2(); o !== e; )
          s2.push(o), o = Yu2();
        $5 = u3, u3 = $t4(r, s2);
      } else
        n2 = u3, u3 = e;
      return u3;
    }
    function T5() {
      var u3, r, s2, o;
      if (u3 = n2, t.charCodeAt(n2) === 94 ? (r = ce5, n2++) : (r = e, h === 0 && d2(Xe5)), r === e && (r = null), s2 = [], o = tu2(), o !== e)
        for (; o !== e; )
          s2.push(o), o = tu2();
      else
        s2 = e;
      return s2 !== e ? ($5 = u3, u3 = mt4(r, s2)) : (n2 = u3, u3 = e), u3;
    }
    function Hu2() {
      var u3, r, s2, o, B5;
      if (u3 = n2, r = [], s2 = n2, o = G4(), o !== e ? (B5 = T5(), B5 !== e ? s2 = B5 : (n2 = s2, s2 = e)) : (n2 = s2, s2 = e), s2 !== e)
        for (; s2 !== e; )
          r.push(s2), s2 = n2, o = G4(), o !== e ? (B5 = T5(), B5 !== e ? s2 = B5 : (n2 = s2, s2 = e)) : (n2 = s2, s2 = e);
      else
        r = e;
      return r !== e && ($5 = u3, r = _t4(r)), u3 = r, u3;
    }
    function Fr2() {
      var u3, r, s2, o, B5;
      if (u3 = n2, r = [], s2 = n2, o = Vu2(), o !== e ? (B5 = T5(), B5 !== e ? s2 = B5 : (n2 = s2, s2 = e)) : (n2 = s2, s2 = e), s2 !== e)
        for (; s2 !== e; )
          r.push(s2), s2 = n2, o = Vu2(), o !== e ? (B5 = T5(), B5 !== e ? s2 = B5 : (n2 = s2, s2 = e)) : (n2 = s2, s2 = e);
      else
        r = e;
      return r !== e && ($5 = u3, r = yt4(r)), u3 = r, u3;
    }
    function hr2() {
      var u3, r, s2, o, B5;
      if (u3 = n2, r = [], s2 = n2, o = Xu2(), o !== e ? (B5 = T5(), B5 !== e ? s2 = B5 : (n2 = s2, s2 = e)) : (n2 = s2, s2 = e), s2 !== e)
        for (; s2 !== e; )
          r.push(s2), s2 = n2, o = Xu2(), o !== e ? (B5 = T5(), B5 !== e ? s2 = B5 : (n2 = s2, s2 = e)) : (n2 = s2, s2 = e);
      else
        r = e;
      return r !== e && ($5 = u3, r = wt4(r)), u3 = r, u3;
    }
    function Ju2() {
      var u3, r, s2;
      return u3 = n2, r = T5(), r !== e ? (s2 = Hu2(), s2 === e && (s2 = Fr2(), s2 === e && (s2 = hr2())), s2 === e && (s2 = null), $5 = u3, u3 = bt4(r, s2)) : (n2 = u3, u3 = e), u3;
    }
    function Ku2() {
      var u3, r, s2;
      return u3 = n2, r = T5(), r !== e ? (s2 = Hu2(), s2 === e && (s2 = null), $5 = u3, u3 = xt4(r, s2)) : (n2 = u3, u3 = e), u3;
    }
    function Br2() {
      var u3, r, s2, o;
      return u3 = n2, E4(), r = Y4(), r !== e ? (E4(), s2 = Ju2(), s2 !== e ? (E4(), o = Y4(), o !== e ? ($5 = u3, u3 = It4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function Cr2() {
      var u3;
      return u3 = yr2(), u3 === e && (u3 = vr2(), u3 === e && (u3 = _r2(), u3 === e && (u3 = dr2(), u3 === e && (u3 = Er2(), u3 === e && (u3 = Dr2(), u3 === e && (u3 = mr2(), u3 === e && (u3 = $r2()))))))), u3;
    }
    function Dr2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 6) === vu2 ? (r = vu2, n2 += 6) : (r = e, h === 0 && d2(Ge2)), r !== e ? (E4(), s2 = J4(), s2 !== e ? ($5 = u3, u3 = kt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function dr2() {
      var u3, r, s2, o, B5;
      return u3 = n2, t.substr(n2, 6) === $u2 ? (r = $u2, n2 += 6) : (r = e, h === 0 && d2(Ye4)), r !== e ? (E4(), s2 = Y4(), s2 !== e ? (o = Gu2(), o !== e ? (B5 = Y4(), B5 !== e ? ($5 = u3, u3 = Nt4(o)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function Er2() {
      var u3, r, s2, o;
      return u3 = n2, t.substr(n2, 6) === mu2 ? (r = mu2, n2 += 6) : (r = e, h === 0 && d2(He3)), r !== e ? (E4(), s2 = ou2(), s2 !== e ? (E4(), o = ou2(), o !== e ? (E4(), ou2(), $5 = u3, u3 = Pt4(s2, o)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function vr2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 4) === _u2 ? (r = _u2, n2 += 4) : (r = e, h === 0 && d2(Je3)), r !== e ? (E4(), s2 = M2(), s2 !== e ? ($5 = u3, u3 = qt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function $r2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 4) === yu2 ? (r = yu2, n2 += 4) : (r = e, h === 0 && d2(Ke3)), r !== e ? (E4(), s2 = M2(), s2 !== e ? ($5 = u3, u3 = jt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function mr2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 4) === wu2 ? (r = wu2, n2 += 4) : (r = e, h === 0 && d2(Qe3)), r !== e ? (E4(), s2 = M2(), s2 !== e ? ($5 = u3, u3 = St3(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function _r2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 4) === bu2 ? (r = bu2, n2 += 4) : (r = e, h === 0 && d2(ut4)), r !== e ? (E4(), s2 = M2(), s2 !== e ? ($5 = u3, u3 = Rt4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function yr2() {
      var u3, r, s2, o, B5;
      if (u3 = n2, t.substr(n2, 5) === xu2 ? (r = xu2, n2 += 5) : (r = e, h === 0 && d2(et5)), r !== e)
        if (E4(), s2 = Y4(), s2 !== e) {
          if (o = [], B5 = au2(), B5 !== e)
            for (; B5 !== e; )
              o.push(B5), B5 = au2();
          else
            o = e;
          o !== e ? (B5 = Y4(), B5 !== e ? ($5 = u3, u3 = Lt4(o)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e);
        } else
          n2 = u3, u3 = e;
      else
        n2 = u3, u3 = e;
      return u3;
    }
    function Fu2() {
      var u3, r, s2, o;
      if (u3 = n2, t.substr(n2, 2) === Iu2 ? (r = Iu2, n2 += 2) : (r = e, h === 0 && d2(tt4)), r !== e) {
        for (s2 = [], o = t.charAt(n2), Su2.test(o) ? n2++ : (o = e, h === 0 && d2(zu2)); o !== e; )
          s2.push(o), o = t.charAt(n2), Su2.test(o) ? n2++ : (o = e, h === 0 && d2(zu2));
        r = [r, s2], u3 = r;
      } else
        n2 = u3, u3 = e;
      return u3;
    }
    function wr2() {
      var u3, r, s2, o, B5, x2, j6, K4;
      if (u3 = n2, t.substr(n2, 3) === ku2 ? (r = ku2, n2 += 3) : (r = e, h === 0 && d2(rt5)), r !== e)
        if (E4(), t.charCodeAt(n2) === 91 ? (s2 = p2, n2++) : (s2 = e, h === 0 && d2(Ou2)), s2 !== e)
          if (E4(), o = J4(), o !== e) {
            for (B5 = [], x2 = n2, j6 = G4(), j6 !== e ? (K4 = J4(), K4 !== e ? ($5 = x2, x2 = Tu2(o, K4)) : (n2 = x2, x2 = e)) : (n2 = x2, x2 = e); x2 !== e; )
              B5.push(x2), x2 = n2, j6 = G4(), j6 !== e ? (K4 = J4(), K4 !== e ? ($5 = x2, x2 = Tu2(o, K4)) : (n2 = x2, x2 = e)) : (n2 = x2, x2 = e);
            x2 = E4(), t.charCodeAt(n2) === 93 ? (j6 = w5, n2++) : (j6 = e, h === 0 && d2(Mu2)), j6 !== e ? ($5 = u3, u3 = Ot4(o, B5)) : (n2 = u3, u3 = e);
          } else
            n2 = u3, u3 = e;
        else
          n2 = u3, u3 = e;
      else
        n2 = u3, u3 = e;
      return u3;
    }
    function br2() {
      var u3;
      return u3 = wr2(), u3 === e && (u3 = Br2()), u3;
    }
    function J4() {
      var u3, r, s2, o, B5;
      if (u3 = n2, r = br2(), r !== e) {
        for (E4(), s2 = [], o = Fu2(); o !== e; )
          s2.push(o), o = Fu2();
        $5 = u3, u3 = Mt3(r);
      } else
        n2 = u3, u3 = e;
      return u3 === e && (u3 = n2, r = Cr2(), r !== e ? (E4(), t.charCodeAt(n2) === 36 ? (s2 = Ae4, n2++) : (s2 = e, h === 0 && d2(nt4)), s2 !== e ? (o = E4(), B5 = J4(), B5 !== e ? ($5 = u3, u3 = zt4(r, B5)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e)), u3;
    }
    function xr2() {
      var u3, r;
      return u3 = n2, r = J4(), r !== e && ($5 = u3, r = Tt3(r)), u3 = r, u3 === e && (u3 = Fu2()), u3;
    }
    function Ir2() {
      var u3;
      return u3 = xr2(), u3;
    }
    function kr2() {
      var u3, r;
      return u3 = n2, E4(), r = Nr2(), r === e && (r = Pr2(), r === e && (r = qr2())), r !== e ? (E4(), $5 = u3, u3 = Zt4(r)) : (n2 = u3, u3 = e), u3;
    }
    function Nr2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 6) === Nu2 ? (r = Nu2, n2 += 6) : (r = e, h === 0 && d2(st4)), r !== e ? (E4(), s2 = M2(), s2 !== e ? ($5 = u3, u3 = Wt3(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function Pr2() {
      var u3, r, s2;
      return u3 = n2, t.substr(n2, 6) === Pu2 ? (r = Pu2, n2 += 6) : (r = e, h === 0 && d2(it5)), r !== e ? (E4(), s2 = M2(), s2 !== e ? ($5 = u3, u3 = Ut4(s2)) : (n2 = u3, u3 = e)) : (n2 = u3, u3 = e), u3;
    }
    function qr2() {
      var u3, r;
      return u3 = n2, t.substr(n2, 4) === qu2 ? (r = qu2, n2 += 4) : (r = e, h === 0 && d2(ft2)), r !== e && ($5 = u3, r = Vt3()), u3 = r, u3;
    }
    function jr2() {
      var u3;
      return u3 = Ir2(), u3 === e && (u3 = kr2()), u3;
    }
    var Sr2 = function(u3) {
      this.type_ = "atom", this.source_ = u3, this.location_ = Zu2();
    }, lu2 = function(u3, r, s2, o) {
      this.type_ = "pattern", this.arguments_ = { alignment: r, _steps: o }, s2 !== void 0 && (this.arguments_.seed = s2), this.source_ = u3;
    }, Rr2 = function(u3, r, s2) {
      this.type_ = u3, this.arguments_ = r, this.source_ = s2;
    }, Lr2 = function(u3, r) {
      this.type_ = "element", this.source_ = u3, this.options_ = r, this.location_ = Zu2();
    }, hu2 = function(u3, r) {
      this.type_ = "command", this.name_ = u3, this.options_ = r;
    }, Bu2 = 0;
    if (eu2 = a2(), i.peg$library)
      return (
        /** @type {any} */
        {
          peg$result: eu2,
          peg$currPos: n2,
          peg$FAILED: e,
          peg$maxFailExpected: fu2,
          peg$maxFailPos: q6
        }
      );
    if (eu2 !== e && n2 === t.length)
      return eu2;
    throw eu2 !== e && n2 < t.length && d2(Gt3()), Yt4(
      fu2,
      q6 < t.length ? t.charAt(q6) : null,
      q6 < t.length ? gu2(q6, q6 + 1) : gu2(q6, q6)
    );
  }
  var Gr2 = [
    "start"
  ];
  typeof BigInt > "u" && (BigInt = function(t) {
    if (isNaN(t)) throw new Error("");
    return t;
  });
  var C4 = BigInt(0);
  var m2 = BigInt(1);
  var ru2 = BigInt(2);
  var Du2 = BigInt(5);
  var N4 = BigInt(10);
  var zr2 = 2e3;
  var A3 = {
    s: m2,
    n: C4,
    d: m2
  };
  function z3(t, i) {
    try {
      t = BigInt(t);
    } catch {
      throw Z4();
    }
    return t * i;
  }
  function S3(t) {
    return typeof t == "bigint" ? t : Math.floor(t);
  }
  function I2(t, i) {
    if (i === C4)
      throw du2();
    const e = Object.create(b.prototype);
    e.s = t < C4 ? -m2 : m2, t = t < C4 ? -t : t;
    const f4 = U5(t, i);
    return e.n = t / f4, e.d = i / f4, e;
  }
  function Q3(t) {
    const i = {};
    let e = t, f4 = ru2, l2 = Du2 - m2;
    for (; l2 <= e; ) {
      for (; e % f4 === C4; )
        e /= f4, i[f4] = (i[f4] || C4) + m2;
      l2 += m2 + ru2 * f4++;
    }
    return e !== t ? e > 1 && (i[e] = (i[e] || C4) + m2) : i[t] = (i[t] || C4) + m2, i;
  }
  var k4 = function(t, i) {
    let e = C4, f4 = m2, l2 = m2;
    if (t != null) if (i !== void 0) {
      if (typeof t == "bigint")
        e = t;
      else {
        if (isNaN(t))
          throw Z4();
        if (t % 1 !== 0)
          throw Qu2();
        e = BigInt(t);
      }
      if (typeof i == "bigint")
        f4 = i;
      else {
        if (isNaN(i))
          throw Z4();
        if (i % 1 !== 0)
          throw Qu2();
        f4 = BigInt(i);
      }
      l2 = e * f4;
    } else if (typeof t == "object") {
      if ("d" in t && "n" in t)
        e = BigInt(t.n), f4 = BigInt(t.d), "s" in t && (e *= BigInt(t.s));
      else if (0 in t)
        e = BigInt(t[0]), 1 in t && (f4 = BigInt(t[1]));
      else if (typeof t == "bigint")
        e = t;
      else
        throw Z4();
      l2 = e * f4;
    } else if (typeof t == "number") {
      if (isNaN(t))
        throw Z4();
      if (t < 0 && (l2 = -m2, t = -t), t % 1 === 0)
        e = BigInt(t);
      else if (t > 0) {
        let a2 = 1, D4 = 0, v2 = 1, g3 = 1, c3 = 1, F4 = 1e7;
        for (t >= 1 && (a2 = 10 ** Math.floor(1 + Math.log10(t)), t /= a2); v2 <= F4 && c3 <= F4; ) {
          let p2 = (D4 + g3) / (v2 + c3);
          if (t === p2) {
            v2 + c3 <= F4 ? (e = D4 + g3, f4 = v2 + c3) : c3 > v2 ? (e = g3, f4 = c3) : (e = D4, f4 = v2);
            break;
          } else
            t > p2 ? (D4 += g3, v2 += c3) : (g3 += D4, c3 += v2), v2 > F4 ? (e = g3, f4 = c3) : (e = D4, f4 = v2);
        }
        e = BigInt(e) * BigInt(a2), f4 = BigInt(f4);
      }
    } else if (typeof t == "string") {
      let a2 = 0, D4 = C4, v2 = C4, g3 = C4, c3 = m2, F4 = m2, p2 = t.replace(/_/g, "").match(/\d+|./g);
      if (p2 === null)
        throw Z4();
      if (p2[a2] === "-" ? (l2 = -m2, a2++) : p2[a2] === "+" && a2++, p2.length === a2 + 1 ? v2 = z3(p2[a2++], l2) : p2[a2 + 1] === "." || p2[a2] === "." ? (p2[a2] !== "." && (D4 = z3(p2[a2++], l2)), a2++, (a2 + 1 === p2.length || p2[a2 + 1] === "(" && p2[a2 + 3] === ")" || p2[a2 + 1] === "'" && p2[a2 + 3] === "'") && (v2 = z3(p2[a2], l2), c3 = N4 ** BigInt(p2[a2].length), a2++), (p2[a2] === "(" && p2[a2 + 2] === ")" || p2[a2] === "'" && p2[a2 + 2] === "'") && (g3 = z3(p2[a2 + 1], l2), F4 = N4 ** BigInt(p2[a2 + 1].length) - m2, a2 += 3)) : p2[a2 + 1] === "/" || p2[a2 + 1] === ":" ? (v2 = z3(p2[a2], l2), c3 = z3(p2[a2 + 2], m2), a2 += 3) : p2[a2 + 3] === "/" && p2[a2 + 1] === " " && (D4 = z3(p2[a2], l2), v2 = z3(p2[a2 + 2], l2), c3 = z3(p2[a2 + 4], m2), a2 += 5), p2.length <= a2)
        f4 = c3 * F4, l2 = /* void */
        e = g3 + f4 * D4 + F4 * v2;
      else
        throw Z4();
    } else if (typeof t == "bigint")
      e = t, l2 = t, f4 = m2;
    else
      throw Z4();
    if (f4 === C4)
      throw du2();
    A3.s = l2 < C4 ? -m2 : m2, A3.n = e < C4 ? -e : e, A3.d = f4 < C4 ? -f4 : f4;
  };
  function Tr2(t, i, e) {
    let f4 = m2;
    for (; i > C4; t = t * t % e, i >>= m2)
      i & m2 && (f4 = f4 * t % e);
    return f4;
  }
  function Zr2(t, i) {
    for (; i % ru2 === C4; i /= ru2)
      ;
    for (; i % Du2 === C4; i /= Du2)
      ;
    if (i === m2)
      return C4;
    let e = N4 % i, f4 = 1;
    for (; e !== m2; f4++)
      if (e = e * N4 % i, f4 > zr2)
        return C4;
    return BigInt(f4);
  }
  function Wr2(t, i, e) {
    let f4 = m2, l2 = Tr2(N4, e, i);
    for (let a2 = 0; a2 < 300; a2++) {
      if (f4 === l2)
        return BigInt(a2);
      f4 = f4 * N4 % i, l2 = l2 * N4 % i;
    }
    return 0;
  }
  function U5(t, i) {
    if (!t)
      return i;
    if (!i)
      return t;
    for (; ; ) {
      if (t %= i, !t)
        return i;
      if (i %= t, !i)
        return t;
    }
  }
  function b(t, i) {
    if (k4(t, i), this instanceof b)
      t = U5(A3.d, A3.n), this.s = A3.s, this.n = A3.n / t, this.d = A3.d / t;
    else
      return I2(A3.s * A3.n, A3.d);
  }
  var du2 = function() {
    return new Error("Division by Zero");
  };
  var Z4 = function() {
    return new Error("Invalid argument");
  };
  var Qu2 = function() {
    return new Error("Parameters must be integer");
  };
  b.prototype = {
    s: m2,
    n: C4,
    d: m2,
    /**
     * Calculates the absolute value
     *
     * Ex: new Fraction(-4).abs() => 4
     **/
    abs: function() {
      return I2(this.n, this.d);
    },
    /**
     * Inverts the sign of the current fraction
     *
     * Ex: new Fraction(-4).neg() => 4
     **/
    neg: function() {
      return I2(-this.s * this.n, this.d);
    },
    /**
     * Adds two rational numbers
     *
     * Ex: new Fraction({n: 2, d: 3}).add("14.9") => 467 / 30
     **/
    add: function(t, i) {
      return k4(t, i), I2(
        this.s * this.n * A3.d + A3.s * this.d * A3.n,
        this.d * A3.d
      );
    },
    /**
     * Subtracts two rational numbers
     *
     * Ex: new Fraction({n: 2, d: 3}).add("14.9") => -427 / 30
     **/
    sub: function(t, i) {
      return k4(t, i), I2(
        this.s * this.n * A3.d - A3.s * this.d * A3.n,
        this.d * A3.d
      );
    },
    /**
     * Multiplies two rational numbers
     *
     * Ex: new Fraction("-17.(345)").mul(3) => 5776 / 111
     **/
    mul: function(t, i) {
      return k4(t, i), I2(
        this.s * A3.s * this.n * A3.n,
        this.d * A3.d
      );
    },
    /**
     * Divides two rational numbers
     *
     * Ex: new Fraction("-17.(345)").inverse().div(3)
     **/
    div: function(t, i) {
      return k4(t, i), I2(
        this.s * A3.s * this.n * A3.d,
        this.d * A3.n
      );
    },
    /**
     * Clones the actual object
     *
     * Ex: new Fraction("-17.(345)").clone()
     **/
    clone: function() {
      return I2(this.s * this.n, this.d);
    },
    /**
     * Calculates the modulo of two rational numbers - a more precise fmod
     *
     * Ex: new Fraction('4.(3)').mod([7, 8]) => (13/3) % (7/8) = (5/6)
     * Ex: new Fraction(20, 10).mod().equals(0) ? "is Integer"
     **/
    mod: function(t, i) {
      if (t === void 0)
        return I2(this.s * this.n % this.d, m2);
      if (k4(t, i), C4 === A3.n * this.d)
        throw du2();
      return I2(
        this.s * (A3.d * this.n) % (A3.n * this.d),
        A3.d * this.d
      );
    },
    /**
     * Calculates the fractional gcd of two rational numbers
     *
     * Ex: new Fraction(5,8).gcd(3,7) => 1/56
     */
    gcd: function(t, i) {
      return k4(t, i), I2(U5(A3.n, this.n) * U5(A3.d, this.d), A3.d * this.d);
    },
    /**
     * Calculates the fractional lcm of two rational numbers
     *
     * Ex: new Fraction(5,8).lcm(3,7) => 15
     */
    lcm: function(t, i) {
      return k4(t, i), A3.n === C4 && this.n === C4 ? I2(C4, m2) : I2(A3.n * this.n, U5(A3.n, this.n) * U5(A3.d, this.d));
    },
    /**
     * Gets the inverse of the fraction, means numerator and denominator are exchanged
     *
     * Ex: new Fraction([-3, 4]).inverse() => -4 / 3
     **/
    inverse: function() {
      return I2(this.s * this.d, this.n);
    },
    /**
     * Calculates the fraction to some integer exponent
     *
     * Ex: new Fraction(-1,2).pow(-3) => -8
     */
    pow: function(t, i) {
      if (k4(t, i), A3.d === m2)
        return A3.s < C4 ? I2((this.s * this.d) ** A3.n, this.n ** A3.n) : I2((this.s * this.n) ** A3.n, this.d ** A3.n);
      if (this.s < C4) return null;
      let e = Q3(this.n), f4 = Q3(this.d), l2 = m2, a2 = m2;
      for (let D4 in e)
        if (D4 !== "1") {
          if (D4 === "0") {
            l2 = C4;
            break;
          }
          if (e[D4] *= A3.n, e[D4] % A3.d === C4)
            e[D4] /= A3.d;
          else return null;
          l2 *= BigInt(D4) ** e[D4];
        }
      for (let D4 in f4)
        if (D4 !== "1") {
          if (f4[D4] *= A3.n, f4[D4] % A3.d === C4)
            f4[D4] /= A3.d;
          else return null;
          a2 *= BigInt(D4) ** f4[D4];
        }
      return A3.s < C4 ? I2(a2, l2) : I2(l2, a2);
    },
    /**
     * Calculates the logarithm of a fraction to a given rational base
     *
     * Ex: new Fraction(27, 8).log(9, 4) => 3/2
     */
    log: function(t, i) {
      if (k4(t, i), this.s <= C4 || A3.s <= C4) return null;
      const e = {}, f4 = Q3(A3.n), l2 = Q3(A3.d), a2 = Q3(this.n), D4 = Q3(this.d);
      for (const c3 in l2)
        f4[c3] = (f4[c3] || C4) - l2[c3];
      for (const c3 in D4)
        a2[c3] = (a2[c3] || C4) - D4[c3];
      for (const c3 in f4)
        c3 !== "1" && (e[c3] = true);
      for (const c3 in a2)
        c3 !== "1" && (e[c3] = true);
      let v2 = null, g3 = null;
      for (const c3 in e) {
        const F4 = f4[c3] || C4, p2 = a2[c3] || C4;
        if (F4 === C4) {
          if (p2 !== C4)
            return null;
          continue;
        }
        let w5 = p2, P3 = F4;
        const R5 = U5(w5, P3);
        if (w5 /= R5, P3 /= R5, v2 === null && g3 === null)
          v2 = w5, g3 = P3;
        else if (w5 * g3 !== v2 * P3)
          return null;
      }
      return v2 !== null && g3 !== null ? I2(v2, g3) : null;
    },
    /**
     * Check if two rational numbers are the same
     *
     * Ex: new Fraction(19.6).equals([98, 5]);
     **/
    equals: function(t, i) {
      return k4(t, i), this.s * this.n * A3.d === A3.s * A3.n * this.d;
    },
    /**
     * Check if this rational number is less than another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    lt: function(t, i) {
      return k4(t, i), this.s * this.n * A3.d < A3.s * A3.n * this.d;
    },
    /**
     * Check if this rational number is less than or equal another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    lte: function(t, i) {
      return k4(t, i), this.s * this.n * A3.d <= A3.s * A3.n * this.d;
    },
    /**
     * Check if this rational number is greater than another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    gt: function(t, i) {
      return k4(t, i), this.s * this.n * A3.d > A3.s * A3.n * this.d;
    },
    /**
     * Check if this rational number is greater than or equal another
     *
     * Ex: new Fraction(19.6).lt([98, 5]);
     **/
    gte: function(t, i) {
      return k4(t, i), this.s * this.n * A3.d >= A3.s * A3.n * this.d;
    },
    /**
     * Compare two rational numbers
     * < 0 iff this < that
     * > 0 iff this > that
     * = 0 iff this = that
     *
     * Ex: new Fraction(19.6).compare([98, 5]);
     **/
    compare: function(t, i) {
      k4(t, i);
      let e = this.s * this.n * A3.d - A3.s * A3.n * this.d;
      return (C4 < e) - (e < C4);
    },
    /**
     * Calculates the ceil of a rational number
     *
     * Ex: new Fraction('4.(3)').ceil() => (5 / 1)
     **/
    ceil: function(t) {
      return t = N4 ** BigInt(t || 0), I2(
        S3(this.s * t * this.n / this.d) + (t * this.n % this.d > C4 && this.s >= C4 ? m2 : C4),
        t
      );
    },
    /**
     * Calculates the floor of a rational number
     *
     * Ex: new Fraction('4.(3)').floor() => (4 / 1)
     **/
    floor: function(t) {
      return t = N4 ** BigInt(t || 0), I2(
        S3(this.s * t * this.n / this.d) - (t * this.n % this.d > C4 && this.s < C4 ? m2 : C4),
        t
      );
    },
    /**
     * Rounds a rational numbers
     *
     * Ex: new Fraction('4.(3)').round() => (4 / 1)
     **/
    round: function(t) {
      return t = N4 ** BigInt(t || 0), I2(
        S3(this.s * t * this.n / this.d) + this.s * ((this.s >= C4 ? m2 : C4) + ru2 * (t * this.n % this.d) > this.d ? m2 : C4),
        t
      );
    },
    /**
      * Rounds a rational number to a multiple of another rational number
      *
      * Ex: new Fraction('0.9').roundTo("1/8") => 7 / 8
      **/
    roundTo: function(t, i) {
      k4(t, i);
      const e = this.n * A3.d, f4 = this.d * A3.n, l2 = e % f4;
      let a2 = S3(e / f4);
      return l2 + l2 >= f4 && a2++, I2(this.s * a2 * A3.n, A3.d);
    },
    /**
     * Check if two rational numbers are divisible
     *
     * Ex: new Fraction(19.6).divisible(1.5);
     */
    divisible: function(t, i) {
      return k4(t, i), !(!(A3.n * this.d) || this.n * A3.d % (A3.n * this.d));
    },
    /**
     * Returns a decimal representation of the fraction
     *
     * Ex: new Fraction("100.'91823'").valueOf() => 100.91823918239183
     **/
    valueOf: function() {
      return Number(this.s * this.n) / Number(this.d);
    },
    /**
     * Creates a string representation of a fraction with all digits
     *
     * Ex: new Fraction("100.'91823'").toString() => "100.(91823)"
     **/
    toString: function(t) {
      let i = this.n, e = this.d;
      t = t || 15;
      let f4 = Zr2(i, e), l2 = Wr2(i, e, f4), a2 = this.s < C4 ? "-" : "";
      if (a2 += S3(i / e), i %= e, i *= N4, i && (a2 += "."), f4) {
        for (let D4 = l2; D4--; )
          a2 += S3(i / e), i %= e, i *= N4;
        a2 += "(";
        for (let D4 = f4; D4--; )
          a2 += S3(i / e), i %= e, i *= N4;
        a2 += ")";
      } else
        for (let D4 = t; i && D4--; )
          a2 += S3(i / e), i %= e, i *= N4;
      return a2;
    },
    /**
     * Returns a string-fraction representation of a Fraction object
     *
     * Ex: new Fraction("1.'3'").toFraction() => "4 1/3"
     **/
    toFraction: function(t) {
      let i = this.n, e = this.d, f4 = this.s < C4 ? "-" : "";
      if (e === m2)
        f4 += i;
      else {
        let l2 = S3(i / e);
        t && l2 > C4 && (f4 += l2, f4 += " ", i %= e), f4 += i, f4 += "/", f4 += e;
      }
      return f4;
    },
    /**
     * Returns a latex representation of a Fraction object
     *
     * Ex: new Fraction("1.'3'").toLatex() => "\frac{4}{3}"
     **/
    toLatex: function(t) {
      let i = this.n, e = this.d, f4 = this.s < C4 ? "-" : "";
      if (e === m2)
        f4 += i;
      else {
        let l2 = S3(i / e);
        t && l2 > C4 && (f4 += l2, i %= e), f4 += "\\frac{", f4 += i, f4 += "}{", f4 += e, f4 += "}";
      }
      return f4;
    },
    /**
     * Returns an array of continued fraction elements
     *
     * Ex: new Fraction("7/8").toContinued() => [0,1,7]
     */
    toContinued: function() {
      let t = this.n, i = this.d, e = [];
      do {
        e.push(S3(t / i));
        let f4 = t % i;
        t = i, i = f4;
      } while (t !== m2);
      return e;
    },
    simplify: function(t) {
      const i = BigInt(1 / (t || 1e-3) | 0), e = this.abs(), f4 = e.toContinued();
      for (let l2 = 1; l2 < f4.length; l2++) {
        let a2 = I2(f4[l2 - 1], m2);
        for (let v2 = l2 - 2; v2 >= 0; v2--)
          a2 = a2.inverse().add(f4[v2]);
        let D4 = a2.sub(e);
        if (D4.n * i < D4.d)
          return a2.mul(this.s);
      }
      return this;
    }
  };
  var L4 = class _L {
    constructor(i, e) {
      this.begin = W4(i), this.end = W4(e);
    }
    get spanCycles() {
      const i = [];
      var e = this.begin;
      const f4 = this.end, l2 = f4.sam();
      if (e.equals(f4))
        return [new _L(e, f4)];
      for (; f4.gt(e); ) {
        if (e.sam().equals(l2)) {
          i.push(new _L(e, this.end));
          break;
        }
        const a2 = e.nextSam();
        i.push(new _L(e, a2)), e = a2;
      }
      return i;
    }
    get duration() {
      return this.end.sub(this.begin);
    }
    cycleArc() {
      const i = this.begin.cyclePos(), e = i.add(this.duration);
      return new _L(i, e);
    }
    withTime(i) {
      return new _L(i(this.begin), i(this.end));
    }
    withEnd(i) {
      return new _L(this.begin, i(this.end));
    }
    withCycle(i) {
      const e = this.begin.sam(), f4 = e.add(i(this.begin.sub(e))), l2 = e.add(i(this.end.sub(e)));
      return new _L(f4, l2);
    }
    intersection(i) {
      const e = this.begin.max(i.begin), f4 = this.end.min(i.end);
      if (!e.gt(f4) && !(e.equals(f4) && (e.equals(this.end) && this.begin.lt(this.end) || e.equals(i.end) && i.begin.lt(i.end))))
        return new _L(e, f4);
    }
    intersection_e(i) {
      const e = this.intersection(i);
      if (e == null)
        throw "TimeSpans do not intersect";
      return e;
    }
    midpoint() {
      return this.begin.add(this.duration.div(W4(2)));
    }
    equals(i) {
      return this.begin.equals(i.begin) && this.end.equals(i.end);
    }
    show() {
      return this.begin.show() + " \u2192 " + this.end.show();
    }
  };
  var Ur2 = (t) => t.filter((i) => i != null);
  b.prototype.sam = function() {
    return this.floor();
  };
  b.prototype.nextSam = function() {
    return this.sam().add(1);
  };
  b.prototype.wholeCycle = function() {
    return new L4(this.sam(), this.nextSam());
  };
  b.prototype.cyclePos = function() {
    return this.sub(this.sam());
  };
  b.prototype.lt = function(t) {
    return this.compare(t) < 0;
  };
  b.prototype.gt = function(t) {
    return this.compare(t) > 0;
  };
  b.prototype.lte = function(t) {
    return this.compare(t) <= 0;
  };
  b.prototype.gte = function(t) {
    return this.compare(t) >= 0;
  };
  b.prototype.eq = function(t) {
    return this.compare(t) == 0;
  };
  b.prototype.ne = function(t) {
    return this.compare(t) != 0;
  };
  b.prototype.max = function(t) {
    return this.gt(t) ? this : t;
  };
  b.prototype.maximum = function(...t) {
    return t = t.map((i) => new b(i)), t.reduce((i, e) => e.max(i), this);
  };
  b.prototype.min = function(t) {
    return this.lt(t) ? this : t;
  };
  b.prototype.mulmaybe = function(t) {
    return t !== void 0 ? this.mul(t) : void 0;
  };
  b.prototype.divmaybe = function(t) {
    return t !== void 0 ? this.div(t) : void 0;
  };
  b.prototype.addmaybe = function(t) {
    return t !== void 0 ? this.add(t) : void 0;
  };
  b.prototype.submaybe = function(t) {
    return t !== void 0 ? this.sub(t) : void 0;
  };
  b.prototype.show = function() {
    return this.s * this.n + "/" + this.d;
  };
  b.prototype.or = function(t) {
    return this.eq(0) ? t : this;
  };
  var W4 = (t) => b(t);
  var cu2 = (...t) => {
    if (t = Ur2(t), t.length === 0)
      return;
    const i = t.pop();
    return t.reduce(
      (e, f4) => e === void 0 || f4 === void 0 ? void 0 : e.lcm(f4),
      i
    );
  };
  W4._original = b;
  var ue6 = 3e-4;
  var Vr2 = (t, i) => (e, f4) => {
    const D4 = t.source_[f4].options_?.ops, v2 = e.__steps_source;
    if (D4)
      for (const g3 of D4)
        switch (g3.type_) {
          case "stretch": {
            const c3 = ["fast", "slow"], { type: F4, amount: p2 } = g3.arguments_;
            if (!c3.includes(F4))
              throw new Error(`mini: stretch: type must be one of ${c3.join("|")} but got ${F4}`);
            e = d(e)[F4](i(p2));
            break;
          }
          case "replicate": {
            const { amount: c3 } = g3.arguments_;
            e = d(e), e = e._repeatCycles(c3)._fast(c3);
            break;
          }
          case "bjorklund": {
            g3.arguments_.rotation ? e = e.euclidRot(i(g3.arguments_.pulse), i(g3.arguments_.step), i(g3.arguments_.rotation)) : e = e.euclid(i(g3.arguments_.pulse), i(g3.arguments_.step));
            break;
          }
          case "degradeBy": {
            e = d(e)._degradeByWith(W2.early(ue6 * g3.arguments_.seed), g3.arguments_.amount ?? 0.5);
            break;
          }
          case "tail": {
            const c3 = i(g3.arguments_.element);
            e = e.fmap((F4) => (p2) => Array.isArray(F4) ? [...F4, p2] : [F4, p2]).appLeft(c3);
            break;
          }
          case "range": {
            const c3 = i(g3.arguments_.element);
            e = d(e);
            const F4 = (w5, P3, R5 = 1) => Array.from(
              { length: Math.abs(P3 - w5) / R5 + 1 },
              (su2, iu2) => w5 < P3 ? w5 + iu2 * R5 : w5 - iu2 * R5
            );
            e = ((w5, P3) => w5.squeezeBind((R5) => P3.bind((su2) => N2(...F4(R5, su2)))))(e, c3);
            break;
          }
          default:
            console.warn(`operator "${g3.type_}" not implemented`);
        }
    return e.__steps_source = e.__steps_source || v2, e;
  };
  function nu2(t, i, e, f4 = 0) {
    e?.(t);
    const l2 = (a2) => nu2(a2, i, e, f4);
    switch (t.type_) {
      case "pattern": {
        const a2 = t.source_.map((c3) => l2(c3)).map(Vr2(t, l2)), D4 = t.arguments_.alignment, v2 = a2.filter((c3) => c3.__steps_source);
        let g3;
        switch (D4) {
          case "stack": {
            g3 = z(...a2), v2.length && (g3._steps = cu2(...v2.map((c3) => W4(c3._steps))));
            break;
          }
          case "polymeter_slowcat": {
            g3 = z(...a2.map((c3) => c3._slow(c3.__weight))), v2.length && (g3._steps = cu2(...v2.map((c3) => W4(c3._steps))));
            break;
          }
          case "polymeter": {
            const c3 = t.arguments_.stepsPerCycle ? l2(t.arguments_.stepsPerCycle).fmap((p2) => m(p2)) : C2(m(a2.length > 0 ? a2[0].__weight : 1)), F4 = a2.map((p2) => p2.fast(c3.fmap((w5) => w5.div(p2.__weight))));
            g3 = z(...F4);
            break;
          }
          case "rand": {
            g3 = Pe2(W2.early(ue6 * t.arguments_.seed).segment(1), a2), v2.length && (g3._steps = cu2(...v2.map((c3) => W4(c3._steps))));
            break;
          }
          case "feet": {
            g3 = N2(...a2);
            break;
          }
          default: {
            if (t.source_.some((F4) => !!F4.options_?.weight)) {
              const F4 = t.source_.reduce(
                (p2, w5) => p2.add(w5.options_?.weight || m(1)),
                m(0)
              );
              g3 = ns(
                ...t.source_.map((p2, w5) => [p2.options_?.weight || m(1), a2[w5]])
              ), g3.__weight = F4, g3._steps = F4, v2.length && (g3._steps = g3._steps.mul(cu2(...v2.map((p2) => W4(p2._steps)))));
            } else
              g3 = Q2(...a2), g3._steps = a2.length;
            t.arguments_._steps && (g3.__steps_source = true);
          }
        }
        return v2.length && (g3.__steps_source = true), g3;
      }
      case "element":
        return l2(t.source_);
      case "atom": {
        if (t.source_ === "~" || t.source_ === "-")
          return q2;
        if (!t.location_)
          return console.warn("no location for", t), t.source_;
        const a2 = isNaN(Number(t.source_)) ? t.source_ : Number(t.source_);
        if (f4 === -1)
          return C2(a2);
        const [D4, v2] = ee4(i, t, f4);
        return C2(a2).withLoc(D4, v2);
      }
      case "stretch":
        return l2(t.source_).slow(l2(t.arguments_.amount));
      default:
        return console.warn(`node type "${t.type_}" not implemented -> returning silence`), q2;
    }
  }
  var ee4 = (t, i, e = 0) => {
    const { start: f4, end: l2 } = i.location_, a2 = t?.split("").slice(f4.offset, l2.offset).join(""), [D4 = 0, v2 = 0] = a2 ? a2.split(i.source_).map((g3) => g3.split("").filter((c3) => c3 === " ").length) : [];
    return [f4.offset + D4 + e, l2.offset - v2 + e];
  };
  var Au2 = (t, i = 0, e = t) => {
    try {
      return Mr2(t);
    } catch (f4) {
      const l2 = [f4.location.start.offset + i, f4.location.end.offset + i], a2 = e.slice(0, l2[0]).split(`
`).length;
      throw new Error(`[mini] parse error at line ${a2}: ${f4.message}`);
    }
  };
  var Xr2 = (t, i, e) => {
    const f4 = Au2(t, i, e);
    let l2 = [];
    return nu2(
      f4,
      t,
      (a2) => {
        a2.type_ === "atom" && l2.push(a2);
      },
      -1
    ), l2;
  };
  var Yr2 = (t, i = 0, e) => Xr2(t, i, e).map((f4) => ee4(t, f4, i));
  var te3 = (...t) => {
    const i = t.map((e) => {
      const f4 = `"${e}"`, l2 = Au2(f4);
      return nu2(l2, f4);
    });
    return Q2(...i);
  };
  var Hr2 = (t, i) => {
    const e = `"${t}"`, f4 = Au2(e);
    return nu2(f4, e, null, i);
  };
  var Jr2 = (t) => {
    const i = Au2(t);
    return nu2(i, t);
  };
  function Kr2(t) {
    return typeof t == "string" ? te3(t) : d(t);
  }
  function Qr2() {
    mh(te3);
  }

  // ../../../../Volumes/PRO-G40/Code/handstrudel/node_modules/@strudel/tonal/dist/index.mjs
  var dist_exports4 = {};
  __export(dist_exports4, {
    addVoicings: () => A1,
    complex: () => w4,
    packageName: () => _1,
    registerVoicings: () => q5,
    resetVoicings: () => O1,
    rootNotes: () => G1,
    scale: () => k1,
    scaleTrans: () => E1,
    scaleTranspose: () => $1,
    setDefaultVoicings: () => y1,
    setVoicingRange: () => T1,
    simple: () => g2,
    strans: () => j1,
    trans: () => I1,
    transpose: () => D1,
    voicing: () => F1,
    voicingAlias: () => D3,
    voicingRegistry: () => v,
    voicings: () => S1
  });
  var import_tonal = __toESM(require_dist44(), 1);
  var import_chord_voicings = __toESM(require_dist45(), 1);
  var P1 = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"];
  var t1 = ["c", "db", "d", "eb", "e", "f", "gb", "g", "ab", "a", "bb", "b"];
  var e1 = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"];
  var n1 = { b: -1, "#": 1 };
  var o1 = (m3) => {
    const [M2, ...P3] = m3.split("");
    return t1.indexOf(M2.toLowerCase()) + P3.reduce((t, e) => t + n1[e], 0);
  };
  function d1(m3) {
    const M2 = (m3 || "").match(/^([A-G][b#]*)([^/]*)[/]?([A-G][b#]*)?$/);
    return M2 ? M2.slice(1) : [];
  }
  var S4 = (m3) => m3 % 12;
  var R4 = (m3) => {
    let M2 = Number(m3);
    return isNaN(M2) ? import_tonal.Interval.semitones(m3) : M2;
  };
  var G3 = (m3, M2) => {
    if (typeof m3 == "number")
      return m3;
    if (typeof m3 == "string")
      return gt2(m3, M2);
  };
  var r1 = (m3, M2 = false) => {
    const P3 = Math.floor(m3 / 12) - 1;
    return (M2 ? e1 : P1)[m3 % 12] + P3;
  };
  function s1(m3, M2, P3 = 1) {
    m3 = m3.map((e) => typeof e == "string" ? gt2(e) : e);
    const t = Math.floor(M2 / m3.length) * P3 * 12;
    return M2 = bt2(M2, m3.length), m3[M2] + t;
  }
  function U6(m3, M2, P3) {
    let t = 0, e = 1 / 0;
    return M2.forEach((n2, s2) => {
      const o = Math.abs(n2 - m3);
      (!P3 && o < e || P3 && o <= e) && (t = s2, e = o);
    }), t;
  }
  var j5 = {};
  function c1(m3, M2, P3, t) {
    const [e, n2] = import_tonal.Scale.tokenize(M2), s2 = G3(e), o = S4(s2);
    if (!j5[n2]) {
      const { intervals: a2 } = import_tonal.Scale.get(`C ${n2}`);
      j5[n2] = a2.map(R4);
    }
    const d2 = j5[n2];
    if (!d2)
      return null;
    let i = s2;
    if (P3) {
      P3 = G3(P3, 3);
      const a2 = S4(P3), l2 = bt2(a2 - o, 12), y3 = U6(l2, d2, t);
      m3 = m3 + y3, i = P3 - l2;
    }
    const c3 = Math.floor(m3 / d2.length) * 12;
    return m3 = bt2(m3, d2.length), d2[m3] + i + c3;
  }
  var H4 = {
    below: (m3) => m3.slice(-1)[0],
    duck: (m3) => m3.slice(-1)[0],
    above: (m3) => m3[0],
    root: (m3) => m3[0]
  };
  function i1({ chord: m3, dictionary: M2, offset: P3 = 0, n: t, mode: e = "below", anchor: n2 = "c5", octaves: s2 = 1 }) {
    const [o, d2] = d1(m3), i = o1(o);
    n2 = G3(n2?.note || n2, 4);
    const c3 = S4(n2), r = M2[d2].map(
      (u3) => (typeof u3 == "string" ? u3.split(" ") : u3).map(R4)
    );
    let a2, l2, y3 = r.map((u3, $5) => {
      const X = H4[e](u3), E4 = bt2(c3 - X - i, 12);
      return (a2 === void 0 || E4 < a2) && (a2 = E4, l2 = $5), E4;
    });
    e === "root" && (l2 = 0);
    const A4 = Math.ceil(P3 / r.length) * 12, N5 = bt2(l2 + P3, r.length), x2 = r[N5], K4 = H4[e](x2), Q4 = n2 - y3[N5] + A4, z4 = x2.map((u3) => Q4 - K4 + u3);
    let V4 = z4.map((u3) => r1(u3));
    return e === "duck" && (V4 = V4.filter((u3, $5) => z4[$5] !== n2)), t !== void 0 ? [s1(V4, t, s2)] : V4;
  }
  var a1 = (m3) => (m3 <= 0 ? -1 : 1) + m3 * 7 + "P";
  function _4(m3) {
    m3 = m3.replaceAll(":", " ");
    const M2 = import_tonal.Scale.get(m3), { tonic: P3, empty: t } = M2;
    if (t && Mt2(m3) || t && !P3)
      throw new Error(
        `Scale name ${m3} is incomplete. Make sure to use ":" instead of spaces, example: .scale("C:major")`
      );
    if (t)
      throw new Error(`Invalid scale name "${m3}"`);
    return M2;
  }
  function l1(m3, M2) {
    m3 = Math.ceil(m3);
    let { intervals: P3, tonic: t } = _4(M2);
    t = t || "C";
    const { pc: e, oct: n2 = 3 } = import_tonal.Note.get(t), s2 = Math.floor(m3 / P3.length), o = bt2(m3, P3.length), d2 = import_tonal.Interval.add(P3[o], a1(s2));
    return import_tonal.Note.transpose(e + n2, d2);
  }
  function J3(m3, M2, P3) {
    let { notes: t } = _4(m3);
    if (t = t.map((r) => import_tonal.Note.get(r).pc), M2 = Number(M2), isNaN(M2))
      throw new Error(`scale offset "${M2}" not a number`);
    const { pc: e, oct: n2 = 3 } = import_tonal.Note.get(P3), s2 = t.indexOf(e);
    if (s2 === -1)
      throw new Error(`note "${P3}" is not in scale "${m3}"`);
    let o = s2, d2 = n2, i = e;
    const c3 = Math.sign(M2);
    for (; Math.abs(o - s2) < Math.abs(M2); ) {
      o += c3;
      const r = bt2(o, t.length);
      c3 < 0 && i[0] === "C" && (d2 += c3), i = t[r], c3 > 0 && i[0] === "C" && (d2 += c3);
    }
    return i + d2;
  }
  var { transpose: D1, trans: I1 } = l(["transpose", "trans"], function(M2, P3) {
    return P3.withHap((t) => {
      const e = t.value.note ?? t.value;
      if (typeof e == "number") {
        let o;
        typeof M2 == "number" ? o = M2 : typeof M2 == "string" && (o = import_tonal.Interval.semitones(M2) || 0);
        const d2 = e + o;
        return typeof t.value == "object" ? t.withValue(() => ({ ...t.value, note: d2 })) : t.withValue(() => d2);
      }
      if (typeof e != "string" || !Mt2(e))
        return E2(`[tonal] transpose: not a note "${e}"`, "warning"), t;
      const n2 = isNaN(Number(M2)) ? String(M2) : import_tonal.Interval.fromSemitones(M2), s2 = import_tonal.Note.transpose(e, n2);
      return typeof t.value == "object" ? t.withValue(() => ({ ...t.value, note: s2 })) : t.withValue(() => s2);
    });
  });
  var { scaleTranspose: $1, scaleTrans: E1, strans: j1 } = l(
    ["scaleTranspose", "scaleTrans", "strans"],
    function(m3, M2) {
      return M2.withHap((P3) => {
        if (!P3.context.scale)
          throw new Error("can only use scaleTranspose after .scale");
        if (typeof P3.value == "object")
          return P3.withValue(() => ({
            ...P3.value,
            note: J3(P3.context.scale, Number(m3), P3.value.note)
          }));
        if (typeof P3.value != "string")
          throw new Error("can only use scaleTranspose with notes");
        return P3.withValue(() => J3(P3.context.scale, Number(m3), P3.value));
      });
    }
  );
  function u1(m3) {
    let M2 = Number(m3), P3 = 0;
    if (isNaN(M2)) {
      m3 = String(m3);
      const t = /^(-?\d+)([#bsf]*)$/.exec(m3);
      if (!t)
        throw new Error(`invalid scale step "${m3}", expected number or integer with optional # b suffixes`);
      M2 = Number(t[1]);
      const e = t[2] || "";
      P3 = Ye2(e);
    }
    return [M2, P3];
  }
  var k5 = {};
  function f1(m3, M2, P3 = true) {
    let t = typeof M2 == "string" ? gt2(M2) : M2;
    if (k5[m3] === void 0) {
      const { intervals: r, tonic: a2 } = _4(m3), { pc: l2 } = import_tonal.Note.get(a2), A4 = r.concat("8P").map((x2) => import_tonal.Note.transpose(l2 + "0", x2)), N5 = A4.map(gt2);
      k5[m3] = [N5, A4];
    }
    const [e, n2] = k5[m3], s2 = e[0], o = Math.floor((t - s2) / 12), d2 = e.map((r) => r + 12 * o), i = U6(t, d2, P3), c3 = n2[i];
    return import_tonal.Note.transpose(c3, import_tonal.Interval.fromSemitones(12 * o));
  }
  var k1 = l(
    "scale",
    function(m3, M2) {
      return Array.isArray(m3) && (m3 = m3.flat().join(" ")), M2.withHaps((P3) => (P3 = P3.map((t) => {
        let e = t.value;
        const n2 = typeof e == "object";
        e = n2 ? e : { n: e };
        const { note: s2, n: o, value: d2, ...i } = e, c3 = s2 ?? o ?? d2;
        if (c3 === void 0)
          return E2(
            `[tonal] Invalid value format for 'scale'. Value must contain n, note, or value but received keys [${Object.keys(e).join(", ")}]`,
            "error"
          ), t;
        let r;
        if (Mt2(c3))
          r = f1(m3, c3), t.value = { ...i, note: r };
        else
          try {
            const [a2, l2] = u1(c3);
            i.anchor ? r = c1(a2, m3, i.anchor) : r = l1(a2, m3), l2 != 0 && (r = import_tonal.Note.transpose(r, import_tonal.Interval.fromSemitones(l2)));
          } catch (a2) {
            zt2(a2, "tonal");
            return;
          }
        return t.value = n2 ? { ...i, note: r } : r, t.setContext({ ...t.context, scale: m3 });
      }), lt2(P3)));
    },
    true,
    true
    // preserve step count
  );
  var g2 = {
    2: ["1P 5P 8P 9M", "1P 5P 8P 9M 12P", "5P 8P 9M 12P"],
    5: ["1P 5P 8P 12P", "5P 8P 12P 15P"],
    6: ["1P 5P 6M 8P 10M", "1P 5P 8P 10M 13M", "3M 5P 8P 10M 13M", "5P 8P 10M 12P 13M"],
    7: [
      "1P 5P 7m 8P 10M",
      "1P 7m 8P 10M 12P",
      "3M 7m 8P 10M 12P",
      "3M 7m 8P 10M 14m",
      "3M 7m 10M 12P 15P",
      "7m 10M 12P 14m 15P",
      "7m 10M 12P 15P 17M"
    ],
    9: [
      "1P 5P 7m 9M 10M",
      "1P 7m 9M 10M 12P",
      "3M 7m 8P 9M 12P",
      "7m 9M 10M 14m 15P",
      "3M 7m 8P 12P 16M",
      "7m 10M 12P 15P 16M"
    ],
    11: ["1P 5P 7m 9M 11P", "5P 7m 8P 9M 11P", "7m 8P 9M 11P 12P", "7m 8P 11P 12P 16M"],
    13: ["1P 6M 7m 9M 10M", "1P 7m 9M 10M 13M", "3M 7m 8P 9M 13M", "7m 8P 9M 10M 13M", "7m 9M 10M 13M 15P"],
    69: ["1P 5P 6M 9M 10M", "1P 5P 9M 10M 13M", "3M 5P 8P 9M 13M", "5P 8P 9M 10M 13M"],
    add9: ["1P 5P 8P 9M 10M", "1P 5P 9M 10M 12P", "3M 8P 9M 10M 12P", "3M 8P 9M 12P 15P", "5P 8P 9M 12P 17M"],
    "+": [
      "1P 3M 6m 8P 10M",
      "1P 6m 8P 10M 13m",
      "3M 6m 8P 10M 13m",
      "3M 8P 10M 13m 15P",
      "6m 8P 10M 13m 15P",
      "6m 10M 13m 15P 17M"
    ],
    o: ["1P 5d 8P 10m 12d", "3m 8P 10m 12d 15P", "5d 8P 10m 12d 15P"],
    h: [
      "3m 5d 7m 8P 10m",
      "1P 5d 7m 10m 12d",
      "3m 7m 8P 10m 12d",
      "3m 7m 8P 12d 14m",
      "5d 7m 8P 10m 14m",
      "5d 8P 10m 12d 14m",
      "7m 10m 12d 14m 15P",
      "5d 8P 10m 14m 17m"
    ],
    sus: ["1P 4P 5P 8P", "1P 4P 5P 8P 11P", "5P 8P 11P 12P", "5P 8P 11P 12P 15P"],
    "^": ["1P 5P 8P 10M", "1P 5P 8P 10M 12P", "3M 5P 8P 10M 12P", "3M 8P 10M 12P 15P", "5P 8P 10M 12P 15P"],
    "-": ["1P 3m 5P 8P 10m", "1P 5P 8P 10m 12P", "3m 5P 8P 10m 12P", "5P 8P 10m 12P 15P"],
    "^7": ["1P 5P 7M 10M 12P", "1P 10M 12P 14M", "3M 8P 10M 12P 14M", "5P 8P 10M 12P 14M", "5P 8P 10M 14M 17M"],
    "-7": [
      "1P 3m 5P 7m 10m",
      "1P 5P 7m 10m 12P",
      "3m 7m 8P 10m 12P",
      "3m 7m 8P 10m 14m",
      "5P 7m 8P 10m 14m",
      "7m 10m 12P 14m 15P",
      "5P 8P 10m 14m 17m",
      "7m 10m 12P 15P 17m"
    ],
    "7sus": ["1P 5P 7m 8P 11P", "5P 8P 11P 12P 14m", "7m 8P 11P 12P 14m", "7m 11P 12P 14m 18P"],
    h7: [
      "3m 5d 7m 8P 10m",
      "1P 5d 7m 10m 12d",
      "1P 7m 10m 12d",
      "3m 7m 8P 10m 12d",
      "3m 7m 8P 12d 14m",
      "5d 7m 8P 10m 14m",
      "5d 8P 10m 12d 14m",
      "7m 10m 12d 14m 15P",
      "5d 8P 10m 14m 17m"
    ],
    o7: [
      "1P 6M 8P 10m 12d",
      "1P 6M 10m 12d 13M",
      "3m 8P 10m 12d 13M",
      "3m 8P 12d 13M 15P",
      "5d 10m 12d 13M 15P",
      "5d 10m 13M 15P 17m",
      "6M 12d 13M 15P 17m",
      "6M 12d 15P 17m 19d"
    ],
    "^9": [
      "1P 5P 7M 9M 10M",
      "1P 7M 9M 10M 12P",
      "3M 7M 8P 9M 12P",
      "3M 7M 8P 12P 16M",
      "5P 8P 10M 14M 16M",
      "7M 8P 10M 12P 16M"
    ],
    "^13": ["1P 6M 7M 9M 10M", "1P 7M 9M 10M 13M", "3M 7M 8P 9M 13M", "3M 7M 8P 13M 16M", "7M 8P 10M 13M 16M"],
    "^7#11": ["1P 5P 7M 10M 12d", "3M 7M 8P 10M 12d", "1P 7M 10M 12d 14M", "3M 7M 8P 12d 14M", "5P 8P 10M 12d 14M"],
    "^9#11": ["1P 3M 5d 7M 9M", "1P 7M 9M 10M 12d", "3M 7M 8P 9M 12d", "3M 8P 9M 12d 14M"],
    "^7#5": ["1P 6m 7M 10M 13m", "3M 7M 8P 10M 13m", "6m 7M 8P 10M 13m"],
    "-6": [
      "1P 3m 5P 6M 8P",
      "1P 5P 6M 8P 10m",
      "3m 5P 6M 8P 10m",
      "1P 5P 8P 10m 13M",
      "3m 5P 8P 10m 13M",
      "5P 8P 10m 12P 13M",
      "5P 8P 10m 13M 15P"
    ],
    "-69": [
      "1P 3m 5P 6M 9M",
      "3m 5P 6M 8P 9M",
      "3m 6M 9M 10m 12P",
      "1P 5P 9M 10m 13M",
      "3m 5P 8P 9M 13M",
      "5P 8P 9M 10m 13M",
      "5P 8P 10m 13M 16M"
    ],
    "-^7": ["1P 3m 5P 7M 10m", "1P 5P 7M 10m 12P", "3m 7M 8P 10m 12P", "5P 7M 8P 10m 14M", "5P 8P 10m 14M 17m"],
    "-^9": ["1P 3m 5P 7M 9M", "1P 7M 9M 10m 12P", "3m 7M 8P 9M 12P", "5P 8P 9M 10m 14M"],
    "-9": [
      "1P 3m 5P 7m 9M",
      "3m 5P 7m 8P 9M",
      "3m 7m 8P 9M 12P",
      "5P 8P 9M 10m 14m",
      "3m 7m 9M 12P 15P",
      "7m 10m 12P 15P 16M"
    ],
    "-add9": ["1P 2M 3m 5P 8P", "1P 3m 5P 9M", "3m 5P 8P 9M 12P", "5P 8P 9M 10m 12P"],
    "-11": [
      "1P 3m 7m 9M 11P",
      "3m 7m 8P 9M 11P",
      "1P 4P 7m 10m 12P",
      "5P 8P 11P 14m",
      "3m 7m 9M 11P 15P",
      "5P 8P 11P 14m 16M",
      "7m 10m 12P 15P 18P"
    ],
    "-7b5": [
      "3m 5d 7m 8P 10m",
      "1P 7m 10m 12d",
      "1P 5d 7m 10m 12d",
      "3m 7m 8P 10m 12d",
      "3m 7m 8P 12d 14m",
      "5d 7m 8P 10m 14m",
      "5d 8P 10m 12d 14m",
      "7m 10m 12d 14m 15P",
      "5d 8P 10m 14m 17m"
    ],
    h9: ["1P 7m 9M 10m 12d", "3m 7m 8P 9M 12d", "5d 8P 9M 10m 14m", "7m 10m 12d 15P 16M"],
    "-b6": ["1P 5P 6m 8P 10m", "1P 5P 8P 10m 13m", "3m 5P 8P 10m 13m", "5P 8P 10m 13m", "5P 8P 10m 13m 15P"],
    "-#5": ["1P 6m 8P 10m 13m", "3m 6m 8P 10m 13m", "6m 8P 10m 13m 15P"],
    "7b9": ["1P 3M 7m 9m 10M", "3M 7m 8P 9m 10M", "3M 7m 8P 9m 14m", "7m 9m 10M 14m 15P"],
    "7#9": ["1P 3M 7m 10m", "3M 7m 8P 10m 14m", "7m 10m 10M 14m 15P"],
    "7#11": ["1P 3M 7m 10M 12d", "3M 7m 8P 10M 12d", "7m 10M 12d 14m 15P"],
    "7b5": ["1P 3M 7m 10M 12d", "3M 7m 8P 10M 12d", "7m 10M 12d 14m 15P"],
    "7#5": ["1P 3M 7m 10M 13m", "3M 7m 8P 10M 13m", "3M 7m 8P 13m 14m", "7m 10M 13m 14m 15P"],
    "9#11": ["1P 7m 9M 10M 12d", "3M 7m 8P 9M 12d", "7m 10M 12d 15P 16M"],
    "9b5": ["1P 7m 9M 10M 12d", "3M 7m 8P 9M 12d", "7m 10M 12d 15P 16M"],
    "9#5": ["1P 7m 9M 10M 13m", "3M 7m 9M 10M 13m", "3M 7m 9M 13m 14m", "7m 10M 13m 14m 16M", "7m 10M 13m 16M 17M"],
    "7b13": ["1P 3M 7m 10M 13m", "3M 7m 8P 10M 13m", "3M 7m 8P 13m 14m", "7m 10M 13m 14m 15P"],
    "7#9#5": ["1P 3M 7m 10m 13m", "3M 7m 10m 13m 15P", "7m 10M 13m 15P 17m"],
    "7#9b5": ["1P 3M 7m 10m 12d", "3M 7m 10m 12d 15P", "7m 10M 12d 15P 17m"],
    "7#9#11": ["1P 3M 7m 10m 12d", "3M 7m 10m 12d 15P", "7m 10M 12d 15P 17m"],
    "7b9#11": ["1P 7m 9m 10M 12d", "3M 7m 8P 9m 12d", "7m 8P 10M 12d 16m"],
    "7b9b5": ["1P 7m 9m 10M 12d", "3M 7m 8P 9m 12d", "7m 8P 10M 12d 16m"],
    "7b9#5": ["1P 7m 9m 10M 13m", "3M 7m 8P 9m 13m", "7m 9m 10M 13m 15P"],
    "7b9#9": ["1P 3M 7m 9m 10m", "3M 7m 8P 9m 10m", "7m 8P 10M 16m 17m"],
    "7b9b13": ["1P 7m 9m 10M 13m", "3M 7m 8P 9m 13m", "7m 9m 10M 13m 15P"],
    "7alt": [
      "3M 7m 8P 9m 12d",
      "1P 7m 10m 10M 13m",
      "3M 7m 8P 10m 13m",
      "3M 7m 9m 12d 15P",
      "3M 7m 10m 13m 15P",
      "7m 10M 12d 15P 17m",
      "7m 10M 13m 15P 17m"
    ],
    "13#11": ["1P 6M 7m 10M 12d", "3M 7m 9M 12d 13M", "7m 10M 12d 13M 16M"],
    "13b9": ["1P 3M 6M 7m 9m", "1P 6M 7m 9m 10M", "3M 7m 9m 10M 13M", "3M 7m 10M 13M 16m", "7m 10M 13M 16m 17M"],
    "13#9": ["1P 3M 6M 7m 10m", "3M 7m 8P 10m 13M", "7m 10M 13M 14m 17m"],
    "7b9sus": ["1P 5P 7m 9m 11P", "5P 7m 8P 9m 11P", "7m 8P 11P 14m 16m"],
    "7susadd3": ["1P 4P 5P 7m 10M", "5P 8P 10M 11P 14m", "7m 11P 12P 15P 17M"],
    "9sus": ["1P 5P 7m 9M 11P", "5P 7m 8P 9M 11P", "7m 8P 9M 11P 12P", "7m 8P 11P 12P 16M"],
    "13sus": ["1P 4P 6M 7m 9M", "1P 7m 9M 11P 13M", "5P 7m 9M 11P 13M", "7m 9M 11P 13M 15P"],
    "7b13sus": ["1P 5P 7m 11P 13m", "5P 7m 8P 11P 13m", "7m 11P 13m 14m 15P"]
  };
  var w4 = {
    2: ["1P 5P 6M 8P 9M", "1P 5P 8P 9M 12P", "5P 8P 9M 12P 13M", "5P 8P 9M 12P 15P"],
    5: ["1P 5P 8P 12P", "1P 5P 8P 9M 12P", "5P 8P 12P 15P", "5P 8P 12P 15P 16M"],
    6: ["1P 5P 6M 9M 10M", "1P 5P 9M 10M 13M", "3M 5P 9M 10M 13M", "5P 8P 9M 10M 13M", "3M 6M 9M 12P 15P"],
    7: [
      "1P 5P 7m 8P 10M",
      "1P 7m 8P 10M 12P",
      "3M 7m 8P 10M 12P",
      "3M 7m 8P 10M 14m",
      "3M 7m 10M 12P 15P",
      "7m 10M 12P 14m 15P",
      "7m 10M 12P 15P 17M",
      "7m 10M 14m 17M 19P"
    ],
    9: [
      "1P 6M 7m 9M 10M",
      "3M 7m 9M 10M 12P",
      "1P 7m 9M 10M 13M",
      "3M 7m 9M 10M 13M",
      "3M 7m 9M 12P 15P",
      "7m 10M 12P 13M 16M",
      "7m 10M 13M 16M 17M",
      "7m 10M 13M 16M 19P"
    ],
    11: [
      "1P 4P 6M 7m 9M",
      "1P 5P 7m 9M 11P",
      "4P 6M 7m 9M 11P",
      "5P 8P 9M 11P 14m",
      "7m 9M 11P 13M 15P",
      "7m 11P 12P 14m 18P"
    ],
    13: [
      "3M 7m 9M 10M 13M",
      "3M 7m 9M 13M 15P",
      "3M 7m 10M 13M 16M",
      "7m 10M 12P 13M 16M",
      "7m 10M 13M 16M 17M",
      "7m 10M 13M 16M 19P"
    ],
    69: ["1P 5P 6M 9M 10M", "1P 5P 9M 10M 13M", "3M 5P 9M 10M 13M", "5P 8P 9M 10M 13M", "3M 6M 9M 12P 15P"],
    add9: [
      "1P 5P 8P 9M 10M",
      "1P 5P 9M 10M 12P",
      "3M 8P 9M 10M 12P",
      "3M 8P 9M 12P 15P",
      "5P 8P 9M 10M 15P",
      "5P 8P 9M 12P 17M"
    ],
    "+": [
      "1P 6m 8P 9M 10M",
      "1P 6m 8P 10M 13m",
      "3M 8P 9M 10M 13m",
      "3M 8P 10M 13m 15P",
      "6m 10M 13m 15P 16M",
      "6m 10M 13m 15P 17M"
    ],
    o: [
      "1P 6M 8P 10m 12d",
      "1P 6M 10m 12d 13M",
      "3m 8P 10m 12d 13M",
      "3m 8P 12d 13M 15P",
      "5d 10m 12d 13M 15P",
      "5d 10m 13M 15P 17m",
      "6M 12d 13M 15P 17m",
      "6M 12d 15P 17m 19d"
    ],
    h: [
      "1P 5d 7m 10m 11P",
      "3m 5d 7m 8P 11P",
      "5d 7m 8P 10m 11P",
      "1P 7m 10m 12d",
      "3m 7m 8P 12d 14m",
      "5d 8P 10m 11P 14m",
      "7m 10m 11P 12d 14m",
      "7m 10m 12d 14m 15P",
      "5d 8P 10m 14m 17m"
    ],
    sus: [
      "1P 4P 5P 8P 9M",
      "1P 4P 5P 8P 11P",
      "1P 5P 8P 9M 11P",
      "5P 8P 9M 11P 12P",
      "5P 8P 11P 12P 13M",
      "5P 8P 11P 13M 15P"
    ],
    "^": [
      "1P 3M 5P 6M 9M",
      "1P 5P 8P 10M 12P",
      "3M 5P 9M 10M 12P",
      "1P 5P 8P 10M 13M",
      "3M 8P 10M 13M 15P",
      "5P 9M 10M 12P 15P"
    ],
    "-": [
      "1P 3m 5P 8P 10m",
      "1P 3m 5P 9M 11P",
      "3m 5P 8P 9M 11P",
      "5P 8P 9M 10m 11P",
      "1P 5P 9M 10m 12P",
      "3m 5P 8P 10m 12P",
      "5P 8P 10m 12P 15P"
    ],
    "^7": [
      "1P 6M 7M 9M 10M",
      "3M 7M 9M 10M 12P",
      "1P 7M 9M 10M 13M",
      "3M 7M 9M 10M 13M",
      "3M 7M 9M 12P 13M",
      "3M 7M 9M 13M 14M",
      "3M 7M 10M 13M 16M",
      "7M 10M 13M 14M 16M",
      "7M 10M 13M 16M 17M",
      "7M 10M 13M 16M 19P"
    ],
    "-7": [
      "1P 3m 5P 7m 9M",
      "1P 3m 5P 7m 10m",
      "1P 5P 7m 10m 11P",
      "3m 7m 8P 10m 11P",
      "1P 5P 7m 10m 12P",
      "3m 7m 9M 10m 12P",
      "3m 7m 8P 10m 14m",
      "5P 7m 9M 10m 14m",
      "7m 10m 11P 14m 15P",
      "7m 10m 12P 15P 16M",
      "5P 8P 11P 14m 17m",
      "7m 10m 12P 15P 17m"
    ],
    "7sus": [
      "1P 4P 6M 7m 9M",
      "1P 5P 7m 9M 11P",
      "4P 6M 7m 9M 11P",
      "5P 8P 9M 11P 14m",
      "7m 9M 11P 13M 15P",
      "7m 11P 12P 14m 18P"
    ],
    h7: [
      "1P 5d 7m 10m 11P",
      "3m 5d 7m 8P 11P",
      "5d 7m 8P 10m 11P",
      "1P 7m 10m 12d",
      "3m 7m 8P 10m 12d",
      "3m 7m 8P 12d 14m",
      "5d 8P 10m 11P 14m",
      "7m 10m 11P 12d 14m",
      "7m 10m 12d 14m 15P",
      "5d 8P 10m 14m 17m"
    ],
    o7: [
      "1P 6M 8P 10m 12d",
      "1P 6M 10m 12d 13M",
      "3m 8P 10m 12d 13M",
      "3m 8P 12d 13M 15P",
      "5d 10m 12d 13M 15P",
      "5d 10m 13M 15P 17m",
      "6M 12d 13M 15P 17m",
      "6M 12d 15P 17m 19d"
    ],
    "^9": [
      "1P 6M 7M 9M 10M",
      "1P 7M 9M 10M 13M",
      "3M 7M 9M 10M 13M",
      "3M 7M 9M 12P 13M",
      "3M 7M 8P 9M 13M",
      "3M 7M 9M 13M 14M",
      "3M 7M 10M 13M 16M",
      "7M 10M 13M 14M 16M",
      "7M 10M 13M 16M 17M",
      "7M 10M 13M 16M 19P"
    ],
    "^13": [
      "1P 6M 7M 9M 10M",
      "1P 7M 9M 10M 13M",
      "3M 7M 9M 12P 13M",
      "3M 7M 9M 10M 13M",
      "3M 7M 8P 9M 13M",
      "3M 7M 9M 13M 14M",
      "3M 7M 10M 13M 16M",
      "7M 10M 13M 14M 16M",
      "7M 10M 13M 16M 17M",
      "7M 10M 13M 16M 19P"
    ],
    "^7#11": [
      "1P 3M 5d 7M 9M",
      "1P 7M 9M 10M 12d",
      "3M 7M 9M 10M 12d",
      "3M 7M 9M 12d 13M",
      "3M 7M 10M 12d 14M",
      "7M 10M 12d 13M 14M",
      "7M 10M 12d 13M 16M",
      "7M 10M 12d 14M 17M"
    ],
    "^9#11": [
      "1P 3M 5d 7M 9M",
      "1P 7M 9M 10M 12d",
      "3M 7M 9M 10M 12d",
      "3M 7M 9M 12d 13M",
      "3M 7M 9M 12d 14M",
      "7M 10M 12d 14M 16M",
      "7M 10M 12d 13M 16M"
    ],
    "^7#5": ["1P 6m 7M 10M 13m", "3M 7M 9M 10M 13m", "3M 7M 10M 13m 14M", "7M 10M 13m 14M 16M", "7M 10M 13m 14M 17M"],
    "-6": [
      "1P 3m 5P 6M 9M",
      "3m 5P 6M 8P 9M",
      "1P 5P 6M 10m 11P",
      "3m 5P 6M 8P 11P",
      "1P 5P 9M 10m 13M",
      "3m 5P 8P 9M 13M",
      "5P 8P 10m 11P 13M",
      "5P 8P 10m 13M 16M"
    ],
    "-69": [
      "1P 3m 5P 6M 9M",
      "3m 5P 6M 8P 9M",
      "3m 6M 9M 10m 12P",
      "1P 5P 9M 10m 13M",
      "3m 5P 8P 9M 13M",
      "5P 8P 9M 10m 13M",
      "5P 8P 10m 13M 16M"
    ],
    "-^7": [
      "1P 3m 5P 7M 9M",
      "1P 5P 7M 10m 11P",
      "3m 7M 9M 10m 11P",
      "3m 7M 9M 10m 12P",
      "3m 7M 9M 12P 14M",
      "7M 10m 11P 12P 14M",
      "7M 10m 12P 14M 16M"
    ],
    "-^9": [
      "1P 3m 5P 7M 9M",
      "1P 5P 7M 10m 11P",
      "3m 7M 9M 10m 11P",
      "3m 7M 9M 10m 12P",
      "3m 7M 9M 12P 14M",
      "7M 10m 11P 12P 14M",
      "7M 10m 12P 14M 16M"
    ],
    "-9": [
      "1P 3m 5P 7m 9M",
      "1P 3m 7m 9M 11P",
      "3m 7m 9M 10m 11P",
      "3m 7m 9M 10m 12P",
      "3m 7m 9M 10m 14m",
      "3m 7m 9M 12P 15P",
      "7m 10m 11P 14m 16M",
      "7m 10m 12P 16M 18P"
    ],
    "-add9": ["1P 2M 3m 5P 8P", "1P 3m 5P 9M", "3m 5P 8P 9M 12P", "5P 8P 9M 10m 12P"],
    "-11": [
      "3m 5P 7m 9M 11P",
      "7m 9M 10m 11P",
      "1P 4P 7m 10m 12P",
      "3m 7m 9M 11P 12P",
      "7m 9M 10m 11P 12P",
      "3m 7m 9M 11P 14m",
      "4P 10m 12P 14m",
      "5P 8P 11P 14m",
      "5P 8P 11P 14m 16M",
      "7m 10m 12P 16M 18P",
      "7m 10m 11P 16M 21m"
    ],
    "-7b5": [
      "1P 5d 7m 10m 11P",
      "3m 5d 7m 8P 11P",
      "5d 7m 8P 10m 11P",
      "1P 7m 10m 12d",
      "3m 7m 8P 10m 12d",
      "3m 7m 8P 12d 14m",
      "5d 8P 10m 11P 14m",
      "7m 10m 11P 12d 14m",
      "7m 10m 12d 14m 15P",
      "5d 8P 10m 14m 17m"
    ],
    h9: [
      "3m 5d 7m 9M 11P",
      "1P 7m 9M 10m 12d",
      "3m 7m 9M 12d 14m",
      "5d 8P 9M 10m 14m",
      "7m 10m 11P 12d 14m",
      "7m 10m 12d 14m 16M"
    ],
    "-b6": ["1P 3m 5P 6m 8P", "3m 5P 8P 11P 13m", "5P 8P 10m 11P 13m"],
    "-#5": ["1P 6m 8P 10m 13m", "3m 6m 8P 11P 13m", "6m 8P 10m 13m 15P"],
    "7b9": ["1P 3M 7m 9m 10M", "3M 7m 8P 9m 10M", "3M 7m 8P 9m 14m", "7m 9m 10M 14m 15P"],
    "7#9": ["1P 3M 7m 10m", "3M 7m 10m 10M 12P", "3M 7m 10m 12P 14m", "7m 10M 12P 14m 17m"],
    "7#11": ["1P 3M 7m 9M 12d", "3M 7m 9M 12d 13M", "7m 10M 12d 13M 16M"],
    "7b5": ["1P 3M 7m 9M 12d", "3M 7m 9M 12d 13M", "7m 10M 12d 13M 16M"],
    "7#5": ["1P 3M 7m 10M 13m", "3M 7m 8P 10M 13m", "3M 7m 8P 13m 14m", "7m 10M 13m 14m 15P", "7m 10M 13m 14m 17M"],
    "9#11": ["1P 7m 9M 10M 12d", "3M 7m 8P 9M 12d", "7m 10M 12d 15P 16M"],
    "9b5": ["1P 7m 9M 10M 12d", "3M 7m 8P 9M 12d", "7m 10M 12d 15P 16M"],
    "9#5": ["1P 7m 9M 10M 13m", "3M 7m 9M 10M 13m", "3M 7m 9M 13m 14m", "7m 10M 13m 14m 16M", "7m 10M 13m 16M 17M"],
    "7b13": ["1P 3M 7m 10M 13m", "3M 7m 8P 10M 13m", "3M 7m 8P 13m 14m", "7m 10M 13m 14m 15P", "7m 10M 13m 14m 17M"],
    "7#9#5": ["3M 7m 10m 10M 13m", "3M 7m 10m 13m 14m", "7m 10M 13m 14m 17m"],
    "7#9b5": ["3M 7m 10m 10M 12d", "3M 7m 10m 12d 14m", "7m 10M 12d 14m 17m"],
    "7#9#11": ["3M 7m 10m 10M 12d", "3M 7m 10m 12d 14m", "7m 10M 12d 14m 17m"],
    "7b9#11": ["3M 7m 9m 10M 12d", "3M 7m 9m 12d 14m", "7m 8P 10M 12d 16m", "7m 10M 12d 14m 16m"],
    "7b9b5": ["3M 7m 9m 10M 12d", "3M 7m 9m 12d 14m", "7m 8P 10M 12d 16m", "7m 10M 12d 14m 16m"],
    "7b9#5": ["1P 7m 9m 10M 13m", "3M 7m 9m 10M 13m", "3M 7m 10M 13m 16m", "7m 10M 13m 14m 16m", "7m 10M 13m 16m 17M"],
    "7b9#9": ["1P 3M 7m 9m 10m", "3M 7m 10m 13m 16m", "7m 10M 13m 16m 17m"],
    "7b9b13": ["1P 7m 9m 10M 13m", "3M 7m 9m 10M 13m", "3M 7m 10M 13m 16m", "7m 10M 13m 14m 16m", "7m 10M 13m 16m 17M"],
    "7alt": [
      "3M 7m 8P 10m 13m",
      "3M 7m 9m 12d 13m",
      "3M 7m 9m 10m 13m",
      "3M 7m 10m 13m 14m",
      "3M 7m 9m 12d 14m",
      "3M 7m 10m 13m 15P",
      "3M 7m 10m 13m 16m",
      "7m 10M 12d 14m 16m",
      "7m 10M 12d 13m 16m",
      "7m 10M 13m 15P 17m",
      "7m 10M 13m 16m 17m",
      "7m 10M 13m 16m 19d"
    ],
    "13#11": ["3M 7m 9M 12d 13M", "7m 10M 12d 13M 16M"],
    "13b9": ["3M 7m 9m 10M 13M", "3M 7m 10M 13M 16m", "7m 10M 13M 16m 17M"],
    "13#9": ["3M 7m 10m 10M 13M", "7m 10M 13M 14m 17m"],
    "7b9sus": ["1P 5P 7m 9m 11P", "5P 7m 8P 9m 11P", "7m 8P 11P 14m 16m"],
    "7susadd3": ["1P 4P 5P 7m 10M", "5P 8P 10M 11P 14m", "7m 11P 12P 15P 17M"],
    "9sus": [
      "1P 4P 6M 7m 9M",
      "1P 5P 7m 9M 11P",
      "4P 6M 7m 9M 11P",
      "5P 8P 9M 11P 14m",
      "7m 9M 11P 13M 15P",
      "7m 11P 12P 14m 18P"
    ],
    "13sus": [
      "1P 4P 6M 7m 9M",
      "1P 7m 9M 11P 13M",
      "4P 7m 9M 11P 13M",
      "7m 9M 11P 13M 15P",
      "7m 11P 13M 14m 16M",
      "7m 11P 13M 16M 18P"
    ],
    "7b13sus": ["1P 5P 7m 11P 13m", "5P 7m 8P 11P 13m", "7m 11P 13m 14m 15P"]
  };
  var { dictionaryVoicing: b1, minTopNoteDiff: g1 } = import_chord_voicings.default.default || import_chord_voicings.default;
  var p1 = {
    m7: ["3m 5P 7m 9M", "7m 9M 10m 12P"],
    7: ["3M 6M 7m 9M", "7m 9M 10M 13M"],
    "^7": ["3M 5P 7M 9M", "7M 9M 10M 12P"],
    69: ["3M 5P 6A 9M"],
    m7b5: ["3m 5d 7m 8P", "7m 8P 10m 12d"],
    "7b9": ["3M 6m 7m 9m", "7m 9m 10M 13m"],
    "7b13": ["3M 6m 7m 9m", "7m 9m 10M 13m"],
    o7: ["1P 3m 5d 6M", "5d 6M 8P 10m"],
    "7#11": ["7m 9M 11A 13A"],
    "7#9": ["3M 7m 9A"],
    mM7: ["3m 5P 7M 9M", "7M 9M 10m 12P"],
    m6: ["3m 5P 6M 9M", "6M 9M 10m 12P"]
  };
  var h1 = {
    m7: ["3m 7m", "7m 10m"],
    m9: ["3m 7m", "7m 10m"],
    7: ["3M 7m", "7m 10M"],
    "^7": ["3M 7M", "7M 10M"],
    "^9": ["3M 7M", "7M 10M"],
    69: ["3M 6M"],
    6: ["3M 6M", "6M 10M"],
    m7b5: ["3m 7m", "7m 10m"],
    "7b9": ["3M 7m", "7m 10M"],
    "7b13": ["3M 7m", "7m 10M"],
    o7: ["3m 6M", "6M 10m"],
    "7#11": ["3M 7m", "7m 10M"],
    "7#9": ["3M 7m", "7m 10M"],
    mM7: ["3m 7M", "7M 10m"],
    m6: ["3m 6M", "6M 10m"]
  };
  var w1 = {
    "": ["1P 3M 5P", "3M 5P 8P", "5P 8P 10M"],
    M: ["1P 3M 5P", "3M 5P 8P", "5P 8P 10M"],
    m: ["1P 3m 5P", "3m 5P 8P", "5P 8P 10m"],
    o: ["1P 3m 5d", "3m 5d 8P", "5d 8P 10m"],
    aug: ["1P 3m 5A", "3m 5A 8P", "5A 8P 10m"]
  };
  var v1 = {
    // triads
    "": ["1P 3M 5P", "3M 5P 8P", "5P 8P 10M"],
    M: ["1P 3M 5P", "3M 5P 8P", "5P 8P 10M"],
    m: ["1P 3m 5P", "3m 5P 8P", "5P 8P 10m"],
    o: ["1P 3m 5d", "3m 5d 8P", "5d 8P 10m"],
    aug: ["1P 3m 5A", "3m 5A 8P", "5A 8P 10m"],
    // sevenths chords
    m7: ["3m 5P 7m 9M", "7m 9M 10m 12P"],
    7: ["3M 6M 7m 9M", "7m 9M 10M 13M"],
    "^7": ["3M 5P 7M 9M", "7M 9M 10M 12P"],
    69: ["3M 5P 6A 9M"],
    m7b5: ["3m 5d 7m 8P", "7m 8P 10m 12d"],
    "7b9": ["3M 6m 7m 9m", "7m 9m 10M 13m"],
    "7b13": ["3M 6m 7m 9m", "7m 9m 10M 13m"],
    o7: ["1P 3m 5d 6M", "5d 6M 8P 10m"],
    "7#11": ["7m 9M 11A 13A"],
    "7#9": ["3M 7m 9A"],
    mM7: ["3m 5P 7M 9M", "7M 9M 10m 12P"],
    m6: ["3m 5P 6M 9M", "6M 9M 10m 12P"]
  };
  var v = {
    lefthand: { dictionary: p1, range: ["F3", "A4"], mode: "below", anchor: "a4" },
    triads: { dictionary: w1, mode: "below", anchor: "a4" },
    guidetones: { dictionary: h1, mode: "above", anchor: "a4" },
    legacy: { dictionary: v1, mode: "below", anchor: "a4" }
  };
  var W5 = "ireal";
  var y1 = (m3) => W5 = m3;
  var T1 = (m3, M2) => A1(m3, v[m3].dictionary, M2);
  var A1 = (m3, M2, P3 = ["F3", "A4"]) => {
    Object.assign(v, { [m3]: { dictionary: M2, range: P3 } });
  };
  var q5 = (m3, M2, P3 = {}) => {
    Object.assign(v, { [m3]: { dictionary: M2, ...P3 } });
  };
  var N1 = (m3, M2, P3) => {
    const { dictionary: t, range: e } = v[M2];
    return b1({
      chord: m3,
      dictionary: t,
      range: e,
      picker: g1,
      lastVoicing: P3
    });
  };
  var C5;
  var S1 = l("voicings", function(m3, M2) {
    return M2.fmap((P3) => (C5 = N1(P3, m3, C5), z(...C5))).outerJoin();
  });
  var G1 = l("rootNotes", function(m3, M2) {
    return M2.fmap((P3) => {
      const n2 = (P3.chord || P3).match(/^([a-gA-G][b#]?).*$/)[1] + m3;
      return P3.chord ? { note: n2 } : n2;
    });
  });
  var F1 = l("voicing", function(m3) {
    return m3.fmap((M2) => {
      M2 = typeof M2 == "string" ? { chord: M2 } : M2;
      let { dictionary: P3 = W5, chord: t, anchor: e, offset: n2, mode: s2, n: o, octaves: d2, ...i } = M2;
      P3 = typeof P3 == "string" ? v[P3] : { dictionary: P3, mode: "below", anchor: "c5" };
      try {
        let c3 = i1({ ...P3, chord: t, anchor: e, offset: n2, mode: s2, n: o, octaves: d2 });
        return z(...c3).note().set(i);
      } catch {
        return E2(`[voicing]: unknown chord "${t}"`), q2;
      }
    }).outerJoin();
  });
  function D3(m3, M2, P3) {
    P3 = Array.isArray(P3) ? P3 : [P3], P3.forEach((t) => {
      t[M2] = t[m3];
    });
  }
  D3("^", "", [g2, w4]);
  Object.keys(g2).forEach((m3) => {
    if (m3.includes("-")) {
      let M2 = m3.replace("-", "m");
      D3(m3, M2, [w4, g2]);
    }
    if (m3.includes("^")) {
      let M2 = m3.replace("^", "M");
      D3(m3, M2, [w4, g2]);
    }
    if (m3.includes("+")) {
      let M2 = m3.replace("+", "aug");
      D3(m3, M2, [w4, g2]);
    }
  });
  q5("ireal", g2);
  q5("ireal-ext", w4);
  function O1() {
    C5 = void 0, y1("ireal");
  }
  var _1 = "@strudel/tonal";

  // strudel-entry.mjs
  window.__hp = {};
  var _evaluate = null;
  var _stop = null;
  var _audioCtx = null;
  var _ready = false;
  function log(msg) {
    console.log("[strudel]", msg);
    window.webkit?.messageHandlers?.strudelBridge?.postMessage({ log: msg });
  }
  window.initStrudel = async function() {
    if (_ready) return "ok";
    try {
      log("registering synth sounds...");
      uc2();
      log("calling evalScope...");
      await xn(dist_exports, dist_exports3, dist_exports4, dist_exports2);
      log("calling initAudio...");
      await Ro2();
      _audioCtx = z2();
      log("audio context ready");
      const r = Dy({
        defaultOutput: De2,
        getTime: () => _audioCtx?.currentTime ?? 0,
        onSchedulerError: (e) => log("sched error: " + e),
        onEvalError: (e) => log("eval error: " + e)
      });
      _evaluate = r.evaluate;
      _stop = r.stop;
      log("repl created");
      if (_audioCtx) {
        let lastBeat = -1;
        const checkBeat = () => {
          try {
            const cpm = window.__hp._cpm || 30;
            const beat = Math.floor(_audioCtx.currentTime * cpm / 60 * 4) % 4;
            if (beat !== lastBeat) {
              lastBeat = beat;
              window.webkit?.messageHandlers?.strudelBridge?.postMessage({ beat });
            }
          } catch {
          }
          requestAnimationFrame(checkBeat);
        };
        checkBeat();
      }
      if (typeof Hydra !== "undefined") {
        try {
          const canvas = document.getElementById("hydra-canvas");
          canvas.width = window.innerWidth || 390;
          canvas.height = window.innerHeight || 844;
          new Hydra({ canvas, detectAudio: false, makeGlobal: true, autoLoop: true });
          window.H = (pat) => () => d(pat).queryArc(Wy(), Wy())[0]?.value ?? 0;
          log("hydra initialized");
        } catch (e) {
          log("hydra init failed: " + e);
        }
      } else {
        log("hydra not available (script not loaded)");
      }
      log("loading drum samples...");
      try {
        await _evaluate(`samples('github:tidalcycles/Dirt-Samples/master')`);
        log("drum samples loaded via evaluate");
      } catch (e) {
        log("evaluate samples error: " + e);
        try {
          if (typeof globalThis.samples === "function") {
            await globalThis.samples("github:tidalcycles/Dirt-Samples/master");
            log("drum samples loaded via globalThis");
          }
        } catch (e2) {
          log("globalThis samples also failed: " + e2);
        }
      }
      log("loading sample-instrument manifests...");
      try {
        await loadBundledInstruments();
        log("sample instruments ready: " + Object.keys(window._sampleInstruments || {}).join(","));
      } catch (e) {
        log("sample manifest load error: " + e);
      }
      _ready = true;
      log("strudel ready");
      return "ok";
    } catch (e) {
      log("initStrudel FAILED: " + e);
      throw e;
    }
  };
  window.strudelEval = async function(code) {
    if (_evaluate) {
      try {
        await _evaluate(code);
      } catch (e) {
        log("eval error: " + e);
      }
    }
  };
  window.hydraEval = function(code) {
    try {
      new Function(code)();
    } catch (e) {
      log("hydra eval: " + e);
    }
  };
  window.strudelStop = function() {
    if (_stop) _stop();
    for (const hand of Object.keys(window._voices || {})) {
      window.noteOff(hand);
    }
  };
  window._drumIntensity = 0.5;
  window._drumComplexity = 0.5;
  window.playHit = function(type) {
    if (!_audioCtx) return;
    const now = _audioCtx.currentTime;
    const vol = 0.3 + window._drumIntensity * 1.2;
    const decay = 0.8 + window._drumComplexity * 1.5;
    const pitchVar = 1 + (window._drumComplexity - 0.5) * 0.3;
    const gain = _audioCtx.createGain();
    if (window._drumComplexity > 0.3) {
      const delay = _audioCtx.createDelay();
      delay.delayTime.value = 0.08 + window._drumComplexity * 0.12;
      const fb = _audioCtx.createGain();
      fb.gain.value = window._drumComplexity * 0.4;
      const wetGain = _audioCtx.createGain();
      wetGain.gain.value = window._drumComplexity * 0.3;
      gain.connect(delay);
      delay.connect(fb);
      fb.connect(delay);
      delay.connect(wetGain);
      wetGain.connect(_audioCtx.destination);
    }
    gain.connect(_audioCtx.destination);
    switch (type) {
      case "kick": {
        const osc = _audioCtx.createOscillator();
        osc.type = "sine";
        osc.frequency.setValueAtTime(150 * pitchVar, now);
        osc.frequency.exponentialRampToValueAtTime(30, now + 0.15 * decay);
        gain.gain.setValueAtTime(vol, now);
        gain.gain.exponentialRampToValueAtTime(1e-3, now + 0.3 * decay);
        osc.connect(gain);
        osc.start(now);
        osc.stop(now + 0.5 * decay);
        break;
      }
      case "snare": {
        const dur = 0.12 * decay;
        const bufSize = _audioCtx.sampleRate * dur;
        const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
        const noise = _audioCtx.createBufferSource();
        noise.buffer = buf;
        const hpf = _audioCtx.createBiquadFilter();
        hpf.type = "highpass";
        hpf.frequency.value = 800 + (1 - window._drumComplexity) * 400;
        const lpf = _audioCtx.createBiquadFilter();
        lpf.type = "lowpass";
        lpf.frequency.value = 4e3 + window._drumIntensity * 4e3;
        gain.gain.setValueAtTime(vol * 0.7, now);
        gain.gain.exponentialRampToValueAtTime(1e-3, now + dur);
        noise.connect(hpf);
        hpf.connect(lpf);
        lpf.connect(gain);
        noise.start(now);
        noise.stop(now + dur + 0.1);
        const osc = _audioCtx.createOscillator();
        const g22 = _audioCtx.createGain();
        g22.connect(_audioCtx.destination);
        osc.type = "triangle";
        osc.frequency.value = 160 * pitchVar;
        g22.gain.setValueAtTime(vol * 0.4, now);
        g22.gain.exponentialRampToValueAtTime(1e-3, now + 0.08 * decay);
        osc.connect(g22);
        osc.start(now);
        osc.stop(now + 0.15 * decay);
        break;
      }
      case "hihat": {
        const dur = (0.02 + window._drumComplexity * 0.08) * decay;
        const bufSize = _audioCtx.sampleRate * dur;
        const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
        const noise = _audioCtx.createBufferSource();
        noise.buffer = buf;
        const hpf = _audioCtx.createBiquadFilter();
        hpf.type = "highpass";
        hpf.frequency.value = 6e3 + (1 - window._drumComplexity) * 4e3;
        gain.gain.setValueAtTime(vol * 0.35, now);
        gain.gain.exponentialRampToValueAtTime(1e-3, now + dur);
        noise.connect(hpf);
        hpf.connect(gain);
        noise.start(now);
        noise.stop(now + dur + 0.1);
        break;
      }
      case "crash": {
        const dur = (0.15 + window._drumComplexity * 0.3) * decay;
        const bufSize = _audioCtx.sampleRate * dur;
        const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
        const noise = _audioCtx.createBufferSource();
        noise.buffer = buf;
        const hpf = _audioCtx.createBiquadFilter();
        hpf.type = "highpass";
        hpf.frequency.value = 4e3;
        gain.gain.setValueAtTime(vol * 0.5, now);
        gain.gain.exponentialRampToValueAtTime(1e-3, now + dur);
        noise.connect(hpf);
        hpf.connect(gain);
        noise.start(now);
        noise.stop(now + dur + 0.1);
        break;
      }
      case "ride": {
        const dur = (0.1 + window._drumComplexity * 0.15) * decay;
        const bufSize = _audioCtx.sampleRate * dur;
        const buf = _audioCtx.createBuffer(1, bufSize, _audioCtx.sampleRate);
        const data = buf.getChannelData(0);
        for (let i = 0; i < bufSize; i++) data[i] = Math.random() * 2 - 1;
        const noise = _audioCtx.createBufferSource();
        noise.buffer = buf;
        const bpf = _audioCtx.createBiquadFilter();
        bpf.type = "bandpass";
        bpf.frequency.value = 5e3 + window._drumComplexity * 2e3;
        bpf.Q.value = 1 + window._drumComplexity * 3;
        gain.gain.setValueAtTime(vol * 0.35, now);
        gain.gain.exponentialRampToValueAtTime(1e-3, now + dur);
        noise.connect(bpf);
        bpf.connect(gain);
        noise.start(now);
        noise.stop(now + dur + 0.1);
        break;
      }
      case "tom": {
        const osc = _audioCtx.createOscillator();
        osc.type = "sine";
        osc.frequency.setValueAtTime(100 * pitchVar, now);
        osc.frequency.exponentialRampToValueAtTime(50, now + 0.15 * decay);
        gain.gain.setValueAtTime(vol * 0.9, now);
        gain.gain.exponentialRampToValueAtTime(1e-3, now + 0.2 * decay);
        osc.connect(gain);
        osc.start(now);
        osc.stop(now + 0.4 * decay);
        break;
      }
    }
  };
  window._sampleInstruments = {};
  var _NOTE_SEMI = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 };
  function _noteNameToMidi(name) {
    const m3 = /^([A-Ga-g])([#sb]?)(-?\d+)$/.exec(name);
    if (!m3) return null;
    let semi = _NOTE_SEMI[m3[1].toUpperCase()];
    if (semi == null) return null;
    if (m3[2] === "#" || m3[2] === "s") semi += 1;
    if (m3[2] === "b") semi -= 1;
    const octave = parseInt(m3[3], 10);
    return (octave + 1) * 12 + semi;
  }
  function _findClosestSampledNote(inst, midi2) {
    let best = null;
    let bestDist = Infinity;
    for (let i = 0; i < inst.midis.length; i++) {
      const d2 = Math.abs(inst.midis[i] - midi2);
      if (d2 < bestDist) {
        bestDist = d2;
        best = i;
      }
    }
    return best == null ? null : { midi: inst.midis[best], url: inst.urls[best] };
  }
  var BUNDLED_MANIFEST = "app-samples://bundled-instruments.json";
  var BUNDLED_AUDIO_BASE = "app-samples://";
  async function loadBundledInstruments() {
    let json;
    try {
      const res = await fetch(BUNDLED_MANIFEST);
      if (!res.ok) throw new Error("HTTP " + res.status);
      json = await res.json();
    } catch (err) {
      log("bundled manifest fetch failed: " + err);
      return;
    }
    const audioDir = (json._audio_dir || "audio").replace(/\/$/, "");
    const baseDir = BUNDLED_AUDIO_BASE + audioDir + "/";
    for (const [instId, notes] of Object.entries(json.instruments || {})) {
      const midis = [];
      const urls = [];
      for (const [noteName, relPath] of Object.entries(notes)) {
        const midi2 = _noteNameToMidi(noteName);
        if (midi2 == null) continue;
        midis.push(midi2);
        urls.push(baseDir + relPath);
      }
      if (!midis.length) continue;
      const order = midis.map((_5, i) => i).sort((a2, b2) => midis[a2] - midis[b2]);
      window._sampleInstruments[instId] = {
        midis: order.map((i) => midis[i]),
        urls: order.map((i) => urls[i])
      };
    }
    log("bundled instruments ready: " + Object.keys(window._sampleInstruments).join(","));
  }
  window._sampleBufferCache = {};
  async function _fetchAndDecode(url) {
    log("  \u2193 " + url);
    let res;
    try {
      res = await fetch(url);
    } catch (e) {
      log("  \u2717 fetch threw: " + e + " (" + url + ")");
      throw e;
    }
    if (!res.ok) {
      log("  \u2717 HTTP " + res.status + " for " + url);
      throw new Error("HTTP " + res.status + " for " + url);
    }
    const ab = await res.arrayBuffer();
    log("  \u2022 got " + ab.byteLength + " bytes for " + url + ", decoding\u2026");
    try {
      const buf = await _audioCtx.decodeAudioData(ab);
      log("  \u2713 decoded " + url + " (" + buf.duration.toFixed(2) + "s)");
      return buf;
    } catch (e) {
      log("  \u2717 decode failed for " + url + ": " + e);
      throw e;
    }
  }
  function _isSampleInstrument(name) {
    return !!(name && window._sampleInstruments[name]);
  }
  window._voices = {};
  function _startSampleVoice(hand, midi2, instName, vel) {
    const inst = window._sampleInstruments[instName];
    if (!inst) return false;
    const slot = { hand, midi: midi2, instName, vel, kind: "sample", armed: true, cancelled: false };
    window._voices[hand] = slot;
    const playWhenReady = (sampledChoice, buffer) => {
      if (slot.cancelled) return;
      const now = _audioCtx.currentTime;
      const v2 = vel || 0.6;
      const semitoneOffset = midi2 - sampledChoice.midi;
      const playbackRate = Math.pow(2, semitoneOffset / 12);
      const src = _audioCtx.createBufferSource();
      src.buffer = buffer;
      src.playbackRate.value = playbackRate;
      const gain = _audioCtx.createGain();
      gain.gain.setValueAtTime(0, now);
      gain.gain.linearRampToValueAtTime(v2 * 0.6, now + 0.01);
      const lpf = _audioCtx.createBiquadFilter();
      lpf.type = "lowpass";
      lpf.frequency.value = 3e3 + v2 * 3e3;
      src.connect(lpf);
      lpf.connect(gain);
      gain.connect(_audioCtx.destination);
      src.start(now);
      slot.armed = false;
      slot.src = src;
      slot.gain = gain;
      slot.lpf = lpf;
      slot.sampledMidi = sampledChoice.midi;
    };
    const choice = _findClosestSampledNote(inst, slot.midi);
    if (!choice) {
      delete window._voices[hand];
      return false;
    }
    const cached = window._sampleBufferCache[choice.url];
    if (cached && cached.buffer) {
      playWhenReady(choice, cached.buffer);
    } else {
      const ensurePromise = cached && cached.then ? cached : (() => {
        log("sample fetch start: " + choice.url);
        const p2 = _fetchAndDecode(choice.url).then((buf) => {
          log("sample fetch ok: " + choice.url + " (" + Math.round(buf.duration * 1e3) + "ms)");
          window._sampleBufferCache[choice.url] = { buffer: buf };
          return buf;
        }).catch((e) => {
          log("sample decode error " + choice.url + ": " + e);
          delete window._sampleBufferCache[choice.url];
          throw e;
        });
        window._sampleBufferCache[choice.url] = p2;
        return p2;
      })();
      ensurePromise.then((buf) => playWhenReady(choice, buf)).catch(() => {
      });
    }
    return true;
  }
  window.noteOn = function(hand, midi2, waveform, vel) {
    if (!_audioCtx) return;
    window.noteOff(hand);
    if (_isSampleInstrument(waveform)) {
      if (_startSampleVoice(hand, midi2, waveform, vel)) return;
    }
    const now = _audioCtx.currentTime;
    const freq = 440 * Math.pow(2, (midi2 - 69) / 12);
    const v2 = vel || 0.6;
    const osc = _audioCtx.createOscillator();
    osc.type = waveform || "sawtooth";
    osc.frequency.setValueAtTime(freq, now);
    const gain = _audioCtx.createGain();
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(v2 * 0.5, now + 0.01);
    const lpf = _audioCtx.createBiquadFilter();
    lpf.type = "lowpass";
    lpf.frequency.value = 3e3 + v2 * 3e3;
    osc.connect(lpf);
    lpf.connect(gain);
    gain.connect(_audioCtx.destination);
    osc.start(now);
    window._voices[hand] = { osc, gain, midi: midi2, kind: "osc" };
  };
  window.noteOff = function(hand) {
    const voice = window._voices[hand];
    if (!voice) return;
    if (voice.kind === "sample" && voice.armed) {
      voice.cancelled = true;
      delete window._voices[hand];
      return;
    }
    const now = _audioCtx.currentTime;
    voice.gain.gain.cancelScheduledValues(now);
    voice.gain.gain.setValueAtTime(voice.gain.gain.value, now);
    voice.gain.gain.exponentialRampToValueAtTime(1e-3, now + 0.05);
    if (voice.kind === "sample") {
      try {
        voice.src.stop(now + 0.06);
      } catch {
      }
    } else {
      try {
        voice.osc.stop(now + 0.06);
      } catch {
      }
    }
    delete window._voices[hand];
  };
  window.noteSlide = function(hand, midi2) {
    const voice = window._voices[hand];
    if (!voice || voice.midi === midi2) return;
    if (voice.kind === "sample" && voice.armed) {
      voice.midi = midi2;
      return;
    }
    if (voice.kind === "sample") {
      const inst = window._sampleInstruments[voice.instName];
      if (!inst) return;
      const choice = _findClosestSampledNote(inst, midi2);
      const currentSampled = voice.sampledMidi != null ? voice.sampledMidi : choice ? choice.midi : midi2;
      if (choice && Math.abs(choice.midi - currentSampled) <= 3) {
        const offset = midi2 - currentSampled;
        const now2 = _audioCtx.currentTime;
        voice.src.playbackRate.setValueAtTime(Math.pow(2, offset / 12), now2);
        voice.midi = midi2;
        voice.sampledMidi = currentSampled;
      } else {
        const wf2 = voice.instName;
        window.noteOff(hand);
        window.noteOn(hand, midi2, wf2, 0.6);
      }
      return;
    }
    const now = _audioCtx.currentTime;
    const freq = 440 * Math.pow(2, (midi2 - 69) / 12);
    voice.osc.frequency.setValueAtTime(freq, now);
    voice.midi = midi2;
  };
  window.playNote = function(midi2, waveform, vel, duration) {
    window.noteOn("oneshot", midi2, waveform, vel);
    setTimeout(() => window.noteOff("oneshot"), (duration || 0.3) * 1e3);
  };
  window.showHydra = function() {
    const c3 = document.getElementById("hydra-canvas");
    if (c3) c3.style.display = "";
  };
  window.hideHydra = function() {
    const c3 = document.getElementById("hydra-canvas");
    if (c3) c3.style.display = "none";
    try {
      new Function("solid(0,0,0,0).out()")();
    } catch {
    }
  };
  window.addEventListener("resize", () => {
    const c3 = document.getElementById("hydra-canvas");
    if (c3) {
      c3.width = window.innerWidth;
      c3.height = window.innerHeight;
    }
  });
  window._moduleReady = true;
  log("module ready");
  window.webkit?.messageHandlers?.strudelBridge?.postMessage({ ready: true });
})();
