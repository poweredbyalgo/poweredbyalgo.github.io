// 禁用shimmer效果的JavaScript - 针对img-link类
(function() {
  'use strict';
  
  // 移除指定元素的shimmer效果
  function removeShimmerFromImgLink(element) {
    if (element.classList.contains('img-link') && element.classList.contains('shimmer')) {
      element.classList.remove('shimmer');
      element.style.background = 'none';
      element.style.animation = 'none';
      element.style.backgroundImage = 'none';
      return true;
    }
    return false;
  }
  
  // 移除所有img-link元素的shimmer效果
  function removeShimmerEffects() {
    // 处理所有img-link元素
    document.querySelectorAll('.img-link').forEach(element => {
      removeShimmerFromImgLink(element);
    });
    
    // 后备方案：处理所有带shimmer类的元素
    document.querySelectorAll('.shimmer').forEach(element => {
      if (element.classList.contains('img-link') || element.querySelector('img')) {
        element.classList.remove('shimmer');
        element.style.background = 'none';
        element.style.animation = 'none';
        element.style.backgroundImage = 'none';
      }
    });
  }
  
  // 监听新添加的元素
  function setupMutationObserver() {
    if (!window.MutationObserver) return;
    
    const observer = new MutationObserver(function(mutations) {
      mutations.forEach(function(mutation) {
        mutation.addedNodes.forEach(function(node) {
          if (node.nodeType === 1) { // 元素节点
            // 检查节点本身
            if (node.classList && node.classList.contains('img-link')) {
              removeShimmerFromImgLink(node);
            }
            
            // 检查子节点
            if (node.querySelectorAll) {
              node.querySelectorAll('.img-link').forEach(imgLink => {
                removeShimmerFromImgLink(imgLink);
              });
            }
          }
        });
      });
    });
    
    observer.observe(document.body, {
      childList: true,
      subtree: true
    });
  }
  
  // 初始化
  function init() {
    removeShimmerEffects();
    setupMutationObserver();
  }
  
  // 页面加载完成后执行
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
  
  // 多次尝试，确保在主题脚本之后执行
  setTimeout(init, 100);
  setTimeout(init, 500);
  setTimeout(init, 1000);
  setTimeout(init, 2000);
  
})();