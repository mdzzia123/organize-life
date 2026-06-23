'use strict';
// Node 18 兼容：若运行环境是 Nodejs18，在 scf_bootstrap 里改为 -r ./polyfill.js
const { File, Blob } = require('node:buffer');
if (typeof globalThis.File === 'undefined') globalThis.File = File;
if (typeof globalThis.Blob === 'undefined') globalThis.Blob = Blob;
