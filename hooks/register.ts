import type { On, PluginOptions, Register } from "claude-code"

// Built-in Explore runs on Haiku with high effort instead of the parent's model
const EXPLORE_MODEL = 'haiku'
const EXPLORE_EFFORT = 'high'

export const register: Register = (on: On, opptions: PluginOptions) => {
  // agentId -> subagent type, so each step's lookup hits $.agent.list() once per agent
  const agentTypes = new Map<string, string>()

  on('ui.render', async ($, e, next) => {
    const ui = $.ui.resolve(e)

    switch(e.component) {
      default: return next(e);
    }
  })

  on('agent.spawn', async ($, e, next) => {
    if (e.subagentType !== 'Explore' || e.fork || e.workflow) return next(e)
    return next({ ...e, model: EXPLORE_MODEL })
  }).catch(($, e, next) => next(e)) // on failure, spawn unchanged rather than block it

  // agent.spawn has no effort field, so set it on each request of an Explore loop
  on('turn.step', async function* ($, e, next) {
    if (!e.agentId) return yield* next(e)
    let type = agentTypes.get(e.agentId)
    if (type === undefined) {
      type = (await $.agent.list()).find((a) => a.id === e.agentId)?.type ?? ''
      agentTypes.set(e.agentId, type)
    }
    if (type !== 'Explore') return yield* next(e)
    return yield* next({ ...e, effort: EXPLORE_EFFORT })
  })
}
