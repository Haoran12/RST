import { createRouter, createWebHistory } from "vue-router";

import ChatView from "@/views/ChatView.vue";

const routes = [
  {
    path: "/",
    name: "chat",
    component: ChatView,
  },
  {
    path: "/session/:id",
    name: "session",
    component: ChatView,
  },
];

export const router = createRouter({
  history: createWebHistory(),
  routes,
});
