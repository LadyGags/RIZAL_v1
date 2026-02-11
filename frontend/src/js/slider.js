// Function to handle switching slides and animations
function nextSlide(step) {
    
    // --- 1. HANDLE CONTENT SLIDES ---
    // Hide all slides
    document.querySelectorAll('.slide').forEach(slide => {
        slide.classList.remove('active');
    });
    
    // Show the target slide (Slide 1, 2, or 3)
    const currentSlide = document.getElementById('slide-' + step);
    if (currentSlide) {
        currentSlide.classList.add('active');
    }

    // --- 2. HANDLE LOGO ANIMATION ---
    const logoContainer = document.getElementById('logoContainer');
    
    if (step === 3) {
        // If entering Login Screen -> Move logos UP
        logoContainer.classList.add('move-up');
    } else {
        // If Welcome/Agree Screen -> Keep logos CENTER
        logoContainer.classList.remove('move-up');
    }

    // --- 3. HANDLE DOT ANIMATION (Sliding Pill) ---
    // Remove 'active' from all dots (they shrink back to circles)
    document.querySelectorAll('.dot').forEach(dot => {
        dot.classList.remove('active');
    });

    // Add 'active' to current dot (it stretches to a pill)
    const currentDot = document.getElementById('dot-' + step);
    if (currentDot) {
        currentDot.classList.add('active');
    }
}