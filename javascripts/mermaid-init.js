document.addEventListener("DOMContentLoaded", function () {
    if (typeof window.mermaid === "undefined") {
        return;
    }

    document.querySelectorAll("pre.mermaid").forEach(function (block) {
        var container = document.createElement("div");
        container.className = "mermaid";
        container.textContent = block.textContent || "";
        block.replaceWith(container);
    });

    window.mermaid.initialize({
        startOnLoad: false
    });

    window.mermaid.run({
        querySelector: ".mermaid"
    });
});
