import { dialog } from "@/utils/message";

const CONFIRM_TITLE = "Leave Current Session?";
const CONFIRM_CONTENT =
  "There are unfinished send/request/RST tasks. Leaving will stop in-flight chat operations and may interrupt updates.";

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
      positiveText: "Leave",
      negativeText: "Stay",
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
