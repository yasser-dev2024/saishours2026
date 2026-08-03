"use strict";

const status = document.querySelector("#download-status");
const downloadButton = document.querySelector("[data-download]");

downloadButton?.addEventListener("click", () => {
  status.textContent = "بدأ التنزيل الآمن من GitHub Releases. انتظر اكتمال الملف ثم افتحه للتثبيت.";
});
