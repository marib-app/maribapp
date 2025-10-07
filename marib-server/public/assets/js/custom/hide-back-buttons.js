/**
 * Script to hide back buttons in reports pages
 */
document.addEventListener('DOMContentLoaded', function() {
    // Check if we're on a reports page
    if (window.location.href.includes('/reports/')) {
        // Find all buttons that match our criteria
        const backButtons = document.querySelectorAll('a.btn.btn-secondary');
        
        backButtons.forEach(button => {
            // Check if the button contains the text "العودة للتقارير" or has the arrow icon
            if (button.textContent.includes('العودة للتقارير') || 
                button.innerHTML.includes('fa-arrow-right') ||
                (button.getAttribute('href') && button.getAttribute('href').includes('reports.index'))) {
                // Hide the button
                button.style.display = 'none';
            }
        });
        
        // Also hide any container that might be specifically for the back button
        const buttonContainers = document.querySelectorAll('.d-flex.justify-content-end');
        buttonContainers.forEach(container => {
            if (container.querySelector('a.btn.btn-secondary')) {
                container.style.display = 'none';
            }
        });
    }
}); 