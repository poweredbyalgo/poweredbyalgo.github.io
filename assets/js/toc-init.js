// TOC initialization for Chirpy theme - 默认显示目录
document.addEventListener('DOMContentLoaded', function() {
  if (typeof tocbot !== 'undefined' && document.getElementById('toc')) {
    const content = document.querySelector('div.content') || document.querySelector('.post-content') || document.querySelector('#post-content') || document.querySelector('main');
    
    if (content && content.querySelector('h2, h3, h4')) {
      tocbot.init({
        tocSelector: '#toc',
        contentSelector: 'div.content',
        headingSelector: 'h2, h3, h4',
        orderedList: false,
        scrollSmooth: false,
        collapseDepth: 6
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