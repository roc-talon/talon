// R-PU45 edge check (slice 121): a consumer that always calls retry() with no delay, max_retries = 1.
// The message must reach the dead letter queue after its second attempt. The dead letter queue has an HTTP pull consumer, so the check reads it from outside.
export default {
  async fetch(req, env) {
    if (new URL(req.url).pathname !== '/send') return new Response('no', { status: 404 });
    await env.MAIN.send({ id: crypto.randomUUID(), at: Date.now() });
    return new Response('sent');
  },
  async queue(batch) {
    for (const m of batch.messages) { console.log(`attempt ${m.attempts} ${m.id}`); m.retry(); }
  },
};
