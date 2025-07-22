importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: "AIzaSyAArKApWyxmDFBChA68MbY1ZYH5vX2VUnY",
  authDomain: "sistema-educativo-rl.firebaseapp.com",
  projectId: "sistema-educativo-rl",
  storageBucket: "sistema-educativo-rl.appspot.com",
  messagingSenderId: "732639994966",
  appId: "1:732639994966:web:f71afd170b50235fe847f7",
});

const messaging = firebase.messaging();