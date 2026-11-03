import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// Same signal as ~/.claude/hooks/bell.sh: the bell_pending user var, which kitty's
// tab_bar.py keeps on the tab until you leave it, then a plain BEL.
const BELL = "\x1b]1337;SetUserVar=bell_pending=MQ==\x07\x07";

export default function (pi: ExtensionAPI) {
	// agent_settled, not agent_end: pi may still retry, compact or run queued work after agent_end.
	pi.on("agent_settled", (_event, ctx) => {
		// Without the TUI, stdout carries print, JSON or RPC output.
		if (ctx.hasUI) process.stdout.write(BELL);
	});
}
