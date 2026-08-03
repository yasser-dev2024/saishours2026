"use strict";

const status = document.querySelector("#download-status");
const downloadButton = document.querySelector("[data-download]");

downloadButton?.addEventListener("click", () => {
  status.textContent = "بدأ تنزيل سايس الخيل. افتح الملف بعد اكتمال التحميل.";
});
