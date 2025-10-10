// TOC initialization for Chirpy theme - 默认显示目录
document.addEventListener('DOMContentLoaded', function() {
  if (typeof tocbot !== 'undefined' && document.getElementById('toc')) {
    const content = document.querySelector('div.content') || document.querySelector('.post-content') || document.querySelector('#post-content') || document.querySelector('main');
    
    if (content && content.querySelector('h2, h3, h4')) {
      // 计算顶部固定元素的高度偏移
      const topbar = document.getElementById('topbar-wrapper');
      const headingsOffset = topbar ? topbar.offsetHeight + 20 : 60; // 默认偏移60px，如果有topbar则加上其高度
      
      tocbot.init({
        tocSelector: '#toc',
        contentSelector: 'div.content',
        headingSelector: 'h2, h3, h4',
        orderedList: false,
        scrollSmooth: false,
        collapseDepth: 6,
        headingsOffset: headingsOffset, // 添加偏移量修正高亮位置
        scrollSmoothOffset: -headingsOffset // 平滑滚动时也应用偏移
      });
      
      const tocWrapper = document.getElementById('toc-wrapper');
      if (tocWrapper) {
        tocWrapper.classList.remove('invisible');
      }
    } else {
      const tocWrapper = document.getElementById('toc-wrapper');
      if (tocWrapper) {
        tocWrapper.style.display = 'none';
      }
    }
  }
});