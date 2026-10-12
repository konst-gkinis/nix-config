import { atom, read, update } from 'claude-code'
import type { Register } from 'claude-code'

import type { CollapsedTurn, OpenTurn } from '../types'

const turns = atom({ plugin: 'collapse-steps', key: 'turns' } as const, [] as CollapsedTurn[])
const open = atom({ plugin: 'collapse-steps', key: 'open' } as const, null as OpenTurn | null)
const isExpanded = atom({ plugin: 'collapse-steps', key: 'isExpanded' } as const, false)

/** Where a row stands: drawn as usual, as the summary line, or not at all. */
type Fate = { kind: 'show' } | { kind: 'head'; turn: CollapsedTurn } | { kind: 'hide' }

const fateOf = (all: CollapsedTurn[], ids: readonly (string | undefined)[]): Fate => {
  for (const turn of all) {
    if (ids.some(id => id === turn.head)) return { kind: 'head', turn }
    if (ids.some(id => id !== undefined && turn.ids.includes(id))) return { kind: 'hide' }
  }
  return { kind: 'show' }
}

const summaryOf = (turn: CollapsedTurn): string => {
  const calls = `${turn.calls} tool call${turn.calls === 1 ? '' : 's'}`
  return `▸ ${calls} hidden · /steps to show`
}

export const register: Register = on => {
  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'steps',
      description: "Show or hide finished turns' tool calls",
    })
    return next(e)
  })

  on('command.run', { command: 'steps' }, async $ => {
    const now = await update($, isExpanded, was => !was)
    return { text: now ? 'Steps shown.' : 'Steps hidden.' }
  })

  on('turn.start', async ($, e, next) => {
    await update($, open, () => ({ turnId: e.turnId, ids: [], calls: 0, lastText: null }))
    return next(e)
  })

  on('session.append', async ($, e, next) => {
    const kept = await next(e)
    if (kept.deny !== undefined || e.agentId !== undefined || e.message.type !== 'assistant') {
      return kept
    }
    const { uuid } = kept

    await update($, open, turn => {
      if (turn === null) return turn
      const ids = [...turn.ids]
      let { calls, lastText } = turn
      for (const block of e.message.content) {
        if (block.type === 'text' && typeof block.text === 'string' && block.text.trim() !== '') {
          if (!ids.includes(uuid)) ids.push(uuid)
          lastText = uuid
        } else if (block.type === 'tool_use' && typeof block.id === 'string') {
          ids.push(block.id)
          calls += 1
          lastText = null
        }
      }
      return { ...turn, ids, calls, lastText }
    })
    return kept
  }).catch(($, e, next) => next(e))

  on('turn.complete', async ($, e, next) => {
    const result = await next(e)
    if (e.agentId !== undefined) return result

    const done = await read($, open)
    if (done === null || done.turnId !== e.turnId) return result
    await update($, open, () => null)

    const ids = done.ids.filter(id => id !== done.lastText)
    const [head] = ids
    if (head !== undefined) {
      await update($, turns, all => [...all, { head, ids, calls: done.calls }])
    }
    return result
  })

  on('ui.render', { component: 'ToolUse' }, async ($, e, next) => {
    if (await read($, isExpanded)) return next(e)
    const fate = fateOf(await read($, turns), [e.props.tool_use_id])
    const { Box, Text } = $.ui.resolve(e)
    if (fate.kind === 'head') return <Text dimColor>{summaryOf(fate.turn)}</Text>
    if (fate.kind === 'hide') return <Box />
    return next(e)
  })

  on('ui.render', { component: 'ToolResult' }, async ($, e, next) => {
    if (await read($, isExpanded)) return next(e)
    const fate = fateOf(await read($, turns), [e.props.tool_use_id])
    const { Box } = $.ui.resolve(e)
    return fate.kind === 'show' ? next(e) : <Box />
  })

  on('ui.render', { component: 'ToolGroup' }, async ($, e, next) => {
    if (await read($, isExpanded)) return next(e)
    const fate = fateOf(await read($, turns), e.props.calls.map(call => call.tool_use_id))
    const { Box, Text } = $.ui.resolve(e)
    if (fate.kind === 'head') return <Text dimColor>{summaryOf(fate.turn)}</Text>
    if (fate.kind === 'hide') return <Box />
    return next(e)
  })

  on('ui.render', { component: 'AssistantMessage' }, async ($, e, next) => {
    if (await read($, isExpanded)) return next(e)
    const fate = fateOf(await read($, turns), [e.requestId])
    const { Box, Text } = $.ui.resolve(e)
    if (fate.kind === 'head') return <Text dimColor>{summaryOf(fate.turn)}</Text>
    if (fate.kind === 'hide') return <Box />
    return next(e)
  })
}
