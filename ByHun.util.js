const ByHun = (function () {
  const util = {};
  let currentApp = null;

  util.SetApp = function ({ name, dev, appID, source }) {
    currentApp = { name, dev, appID, source };
  };

  util.ShowAppToast = function () {
    if (!currentApp) return console.error("SetApp must be called first");

    const toast = document.createElement("div");
    toast.className = "byhun-toast";
    toast.innerHTML = `
      <span>${currentApp.name} is now available on ByHun!</span>
      <button class="byhun-toast-btn">View Info</button>
    `;
    document.body.appendChild(toast);

    const style = document.createElement("style");
    style.innerHTML = `
      .byhun-toast {
        position: fixed;
        bottom: 20px;
        right: 20px;
        background: #1e1e1e;
        color: #fff;
        padding: 15px 20px;
        border-radius: 10px;
        font-family: sans-serif;
        box-shadow: 0 4px 12px rgba(0,0,0,0.3);
        display: flex;
        align-items: center;
        gap: 15px;
        z-index: 9999;
        animation: byhun-toast-slide 0.5s ease-out;
      }
      .byhun-toast-btn {
        background: #00bfff;
        border: none;
        padding: 8px 12px;
        border-radius: 6px;
        color: white;
        cursor: pointer;
        font-weight: bold;
      }
      @keyframes byhun-toast-slide {
        from { transform: translateX(100%); opacity: 0; }
        to { transform: translateX(0); opacity: 1; }
      }
      .byhun-modal-overlay {
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0,0,0,0.6);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 9998;
      }
      .byhun-modal {
        background: #fff;
        padding: 30px;
        border-radius: 15px;
        max-width: 400px;
        width: 90%;
        font-family: sans-serif;
        text-align: center;
        box-shadow: 0 8px 20px rgba(0,0,0,0.4);
      }
      .byhun-modal h2 {
        margin-top: 0;
        color: #333;
      }
      .byhun-modal p {
        margin: 10px 0;
        color: #555;
      }
      .byhun-modal a, .byhun-modal button {
        display: inline-block;
        margin: 10px 5px 0 5px;
        padding: 10px 15px;
        border-radius: 8px;
        border: none;
        background: #00bfff;
        color: #fff;
        text-decoration: none;
        font-weight: bold;
        cursor: pointer;
      }
      .byhun-modal-close {
        background: #ff4d4d !important;
      }
    `;
    document.head.appendChild(style);

    toast.querySelector(".byhun-toast-btn").addEventListener("click", () => {
      util.ShowAppModal();
    });

    setTimeout(() => {
      toast.remove();
    }, 6000);
  };

  util.ShowAppModal = function () {
    if (!currentApp) return console.error("SetApp must be called first");

    const overlay = document.createElement("div");
    overlay.className = "byhun-modal-overlay";

    const modal = document.createElement("div");
    modal.className = "byhun-modal";
    modal.innerHTML = `
      <h2>${currentApp.name}</h2>
      <p><strong>Developer:</strong> ${currentApp.dev}</p>
      <p><strong>AppID:</strong> ${currentApp.appID}</p>
      <p><strong>Source:</strong> ${currentApp.source}</p>
      <button onclick="window.open('https://byhun.gt.tc', '_blank')">Download ByHun</button>
      <button class="byhun-modal-close">Close</button>
    `;

    overlay.appendChild(modal);
    document.body.appendChild(overlay);

    modal.querySelector(".byhun-modal-close").addEventListener("click", () => {
      overlay.remove();
    });

    overlay.addEventListener("click", (e) => {
      if (e.target === overlay) overlay.remove();
    });
  };

  return { util };
})();
