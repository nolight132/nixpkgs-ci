const CHANNEL = "https://channels.nixos.org/nixos-unstable/git-revision";

export default {
  async scheduled(event, env, ctx) {
    ctx.waitUntil(tick(env));
  },

  async fetch(request, env) {
    if (new URL(request.url).pathname !== "/tick") {
      return new Response("nixpkgs-ci watchdog", { status: 200 });
    }

    const secret = env.TICK_SECRET;
    const offered = request.headers.get("authorization");

    if (!secret || offered !== `Bearer `) {
      return new Response("not found", { status: 404 });
    }

    return new Response(JSON.stringify(await tick(env), null, 1), {
      headers: { "content-type": "application/json" },
    });
  },
};

async function tick(env) {
  const revision = await channelRevision();
  const previous = await env.STATE.get("revision");
  const dispatchedAt = Number(await env.STATE.get("dispatched_at")) || 0;

  const now = Date.now();
  const floor = Number(env.FLOOR_MINUTES || "15") * 60_000;

  const moved = revision !== null && revision !== previous;
  const stale = now - dispatchedAt >= floor;

  if (!moved && !stale) {
    return { dispatched: false, revision, reason: "unchanged" };
  }

  await dispatch(env);
  await env.STATE.put("dispatched_at", String(now));
  if (revision !== null) await env.STATE.put("revision", revision);

  return { dispatched: true, revision, reason: moved ? "channel moved" : "floor" };
}

async function channelRevision() {
  const response = await fetch(CHANNEL, { cf: { cacheTtl: 0 } });
  if (!response.ok) return null;
  return (await response.text()).trim();
}

async function dispatch(env) {
  const response = await fetch(
    `https://api.github.com/repos/${env.REPO}/actions/workflows/watch.yml/dispatches`,
    {
      method: "POST",
      headers: {
        authorization: `Bearer ${env.GITHUB_TOKEN}`,
        accept: "application/vnd.github+json",
        "x-github-api-version": "2022-11-28",
        "user-agent": "nixpkgs-ci-watchdog",
      },
      body: JSON.stringify({ ref: env.REF || "main" }),
    },
  );

  if (!response.ok) {
    throw new Error(`dispatch failed: ${response.status} ${await response.text()}`);
  }
}
