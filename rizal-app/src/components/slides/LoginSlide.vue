<script setup>
import Pagination from '../Pagination.vue';
import { ref, onMounted } from 'vue';

import ErrorModal from '../ErrorModal.vue';

const emit = defineEmits(['next', 'create-account']);

const email = ref('');
const password = ref('');
const isLoading = ref(false);
const errorState = ref({
    show: false,
    message: ''
});

const showError = (msg) => {
    errorState.value = {
        show: true,
        message: msg
    };
};

const closeError = () => {
    errorState.value.show = false;
};

const validateLogin = async () => {
    // 1. Basic Input Validation
    if (!email.value || !password.value) {
        showError("Please enter both email and password.");
        return;
    }

    // 2. ReCaptcha Validation
    // This looks for the 'g-recaptcha-response' token or checks the widget
    if (window.grecaptcha && window.grecaptcha.getResponse().length === 0) {
        showError("Please check the 'I'm not a robot' box.");
        return;
    }

    isLoading.value = true;

    try {
        // --- BACKEND API INTEGRATION POINT ---
        // Replace the mock simulation below with your actual API call.
        // Example:
        // const response = await fetch('https://your-api.com/auth/login', {
        //     method: 'POST',
        //     headers: { 'Content-Type': 'application/json' },
        //     body: JSON.stringify({ 
        //         email: email.value, 
        //         password: password.value,
        //         captcha: window.grecaptcha.getResponse()
        //     })
        // });
        // const data = await response.json();
        // if (!response.ok) throw new Error(data.message);
        
        // --- SIMULATION (Delete this block when backend is ready) ---
        console.log("Simulating API call...", { 
            email: email.value, 
            captcha: window.grecaptcha ? window.grecaptcha.getResponse() : 'mock-token' 
        });
        await new Promise(resolve => setTimeout(resolve, 1000)); // Fake delay
        // -------------------------------------------------------------

        // On Success:
        emit('next');

    } catch (error) {
        // Handle Login Errors
        showError("Login Failed: " + error.message);
        // Reset ReCaptcha on error so user can try again
        if (window.grecaptcha) window.grecaptcha.reset();
    } finally {
        isLoading.value = false;
    }
};



const createAccount = () => {
    emit('create-account');
};

onMounted(() => {
    if (window.grecaptcha && window.grecaptcha.render) {
        try {
            window.grecaptcha.render('recaptcha-container', {
                'sitekey': '6LcwPGYsAAAAAJM344gXtvBszYY0hIY69zaavxaH', // Replace with your actual site key if different
                'theme': 'dark'
            });
        } catch (e) {
            // Already rendered or error
            console.log("ReCaptcha render error (might be already rendered):", e);
        }
    }
});
</script>

<template>
  <div class="flex flex-col animate-fadeIn w-full">
    <div class="flex flex-col">
      <h1 class="text-[2rem] sm:text-[2.5rem] leading-[1.1] mb-[1rem] sm:mb-[1.5rem] font-bold">
        Log <span class="text-[#ffc107]">In.</span>
      </h1>

      <form @submit.prevent="validateLogin">
        <div class="mb-[0.8rem] sm:mb-[1.2rem]">
          <label class="block text-[0.8rem] mb-[0.3rem] text-[#ccc]">Email</label>
          <input 
            v-model="email"
            type="email" 
            placeholder="Enter your email"
            class="w-full p-[0.8rem] sm:p-[1rem] bg-[rgba(255,255,255,0.1)] border border-[rgba(255,255,255,0.2)] rounded-[12px] text-white outline-none focus:border-[#ffc107]"
          >
        </div>

        <div class="mb-[0.8rem] sm:mb-[1.2rem]">
          <label class="block text-[0.8rem] mb-[0.3rem] text-[#ccc]">Password</label>
          <input 
            v-model="password"
            type="password" 
            placeholder="Enter your password"
            class="w-full p-[0.8rem] sm:p-[1rem] bg-[rgba(255,255,255,0.1)] border border-[rgba(255,255,255,0.2)] rounded-[12px] text-white outline-none focus:border-[#ffc107]"
          >
        </div>
        
        <a href="#" class="block text-right text-[#ccc] no-underline text-[0.8rem] mb-[1rem] sm:mb-[2rem]">Forgot Password?</a>
        
        <!-- Recaptcha Container -->
        <div id="recaptcha-container" class="mb-[0.5rem] sm:mb-[1rem] flex justify-center transform scale-75 sm:scale-85 origin-center"></div>
        
        <Pagination :currentSlide="3" class="mb-2" />

        <button 
          type="button" 
          class="w-full p-[0.8rem] sm:p-[0.9rem] rounded-[20px] text-[0.9rem] sm:text-[1rem] font-semibold cursor-pointer shadow-[0_4px_15px_rgba(48,79,254,0.4)] z-[200] shrink-0 text-white mt-0 mb-0 bg-gradient-to-r from-[#1a237e] to-[#304ffe] disabled:opacity-70 disabled:cursor-not-allowed"
          @click="validateLogin"
          :disabled="isLoading"
        >
          {{ isLoading ? 'Logging in...' : 'Log In' }}
        </button>
        
        <button 
          type="button" 
          class="w-full p-[0.8rem] sm:p-[1rem] bg-transparent text-[#b0b0b0] border border-[rgba(255,255,255,0.15)] rounded-[20px] text-[0.9rem] sm:text-[1rem] font-semibold cursor-pointer mt-[0.5rem] sm:mt-[0.6rem] transition-all duration-300 z-[200] hover:bg-[rgba(255,255,255,0.05)] hover:border-[rgba(255,193,7,0.4)] hover:text-[#ffc107]"
          @click="createAccount"
        >
          Create Account
        </button>
      </form>
    </div>

    <Teleport to="body">
        <ErrorModal v-if="errorState.show" :message="errorState.message" @close="closeError" />
    </Teleport>
  </div>
</template>
