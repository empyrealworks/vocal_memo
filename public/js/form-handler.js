// js/form-handler.js

// Initialize Firebase (reuse same config)
const firebaseConfig = {
  apiKey: "AIzaSyBA2x94UXSuHE-OlaVu0QNEVa4tFA-lPMA",
  authDomain: "empyreal-works.firebaseapp.com",
  projectId: "empyreal-works",
  storageBucket: "empyreal-works.firebasestorage.app",
  messagingSenderId: "449809138126",
  appId: "1:449809138126:web:c6afdabf5db0d948df2b9f",
  measurementId: "G-0WBYYR80BS"
};

if (!firebase.apps.length) {
  firebase.initializeApp(firebaseConfig);
}
const db = firebase.firestore();

// Generic form handler
function handleFormSubmit(formId, collection,) {
  const form = document.getElementById(formId);
  if (!form) return;

  form.addEventListener("submit", (e) => {
    e.preventDefault();
    const fields = {};
    form.querySelectorAll("input, textarea").forEach((input) => {
      fields[input.id] = input.value.trim();
    });

    db.collection(collection)
      .add({
        ...fields,
        timestamp: firebase.firestore.FieldValue.serverTimestamp(),
      })
      .then(() => {
        form.reset();
        // Hide form and show success message
        form.classList.add('inactive');
        document.getElementById('success-message').classList.add('active');

        // Scroll to success message
        document.getElementById('success-message').scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        });
      })
      .catch((err) => {
        console.error(err);
        alert("Sorry, there was an error. Please try again.");
      });
  });
}

function resetForm(formId) {
   const form = document.getElementById(formId);
  // Reset form
  form.reset();

  // Hide success message
  document.getElementById('success-message').classList.remove('active');
  // Show form
  form.classList.remove('inactive');

  // Scroll back to plans
  document.querySelector('.contact').scrollIntoView({
    behavior: 'smooth',
    block: 'start',
  });
}



// Initialize both forms (if present)
document.addEventListener("DOMContentLoaded", () => {
  handleFormSubmit("contactForm", "inquiries",);
  handleFormSubmit("closedTestForm", "inquiries");
});
