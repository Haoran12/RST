import { dialog } from "@/utils/message";

const CONFIRM_TITLE = "离开当前 Session？";
const CONFIRM_CONTENT =
  "当前仍有正在执行的请求-响应或 RST data 状态更新。仍然离开会先执行 Stop 并立即中断未完成更新。";

export function confirmLeaveSessionWhileBusy(): Promise<boolean> {
  return new Promise((resolve) => {
    let settled = false;
    const settle = (value: boolean) => {
      if (settled) {
        return;
      }
      settled = true;
      resolve(value);
    };

    dialog.warning({
      title: CONFIRM_TITLE,
      content: CONFIRM_CONTENT,
      positiveText: "仍然离开",
      negativeText: "留下",
      maskClosable: false,
      closeOnEsc: false,
      onPositiveClick: () => {
        settle(true);
      },
      onNegativeClick: () => {
        settle(false);
      },
      onClose: () => {
        settle(false);
      },
    });
  });
}
