import type { On, PluginOptions, Register } from "claude-code"

const EXPLORE_MODEL = 'haiku'
const EXPLORE_EFFORT = 'high'

export const register: Register = (on: On, options: PluginOptions) => {
  const agentTypes = new Map<string, string>()

  on('agent.spawn', async ($, e, next) => {
    if (e.subagentType !== 'Explore' || e.fork || e.workflow) return next(e)
    return next({ ...e, model: EXPLORE_MODEL })
  }).catch(($, e, next) => next(e))

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
