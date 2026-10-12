import { expect, test } from 'claude-code/testing'
import type { On, RenderPropsOf } from 'claude-code'
import type { Engine } from 'claude-code/testing'

const ENGINE_ROW = 'ENGINE_ROW'
const TURN_ID = 'TURN_ID'
const NARRATION_UUID = 'NARRATION_UUID'
const ANSWER_UUID = 'ANSWER_UUID'

/** Stands in for the engine: its own rows draw as ENGINE_ROW, turns just echo. */
const engineBeneath = (on: On) => {
  on('ui.render', ($, e) => {
    const { Text } = $.ui.resolve(e)
    return <Text>{ENGINE_ROW}</Text>
  })
  on('turn.start', (_$, e) => ({ turnId: e.turnId }))
  on('turn.complete', (_$, e) => ({ text: e.answer }))
}

const buildToolUseProps = (
  overrides: Partial<RenderPropsOf['ToolUse']> = {},
): RenderPropsOf['ToolUse'] => ({
  tool_use_id: `TOOL_USE_ID_${crypto.randomUUID()}`,
  tool: 'Bash',
  input: { command: 'COMMAND' },
  isRunning: false,
  isErrored: false,
  isInterrupted: false,
  output: { stdout: 'STDOUT', stderr: '' },
  ...overrides,
})

const appendAssistantRow = ($: Engine, uuid: string, content: { type: string; [k: string]: unknown }[]) =>
  $.session.append({
    message: { type: 'assistant', role: 'assistant', content },
    door: 'response',
    origin: { kind: 'model', model: 'MODEL' },
    uuid,
  })

/** A turn of narration, the given tool calls, then an answer; ended unless `isFinished` is false. */
const runTurn = async ($: Engine, toolUseIds: string[], { isFinished = true } = {}) => {
  await $.turn.start({ text: 'PROMPT', turnId: TURN_ID })
  await appendAssistantRow($, NARRATION_UUID, [{ type: 'text', text: 'NARRATION' }])
  for (const id of toolUseIds) {
    await appendAssistantRow($, `ROW_${id}`, [{ type: 'tool_use', id, name: 'Bash', input: {} }])
  }
  await appendAssistantRow($, ANSWER_UUID, [{ type: 'text', text: 'ANSWER' }])
  if (isFinished) {
    await $.turn.complete({ turnId: TURN_ID, answer: 'ANSWER', durationMs: 1, isAborted: false, reason: 'answer' })
  }
}

const mountToolUse = ($: Engine, props: RenderPropsOf['ToolUse']) =>
  $.ui.mount({ plugin: 'collapse-steps', surface: 'terminal', component: 'ToolUse', props, requestId: props.tool_use_id })

const mountMessage = ($: Engine, uuid: string) =>
  $.ui.mount({
    plugin: 'collapse-steps',
    surface: 'terminal',
    component: 'AssistantMessage',
    props: { text: 'TEXT', isFirstOfReply: true },
    requestId: uuid,
  })

test("a finished turn's narration draws as the summary line", async ($, on) => {
  engineBeneath(on)
  await runTurn($, ['TOOL_USE_ID'])

  const ui = await mountMessage($, NARRATION_UUID)

  expect((await ui.find({ type: 'Text' }))?.text).toBe('▸ 1 tool call hidden · /steps to show')
})

test("a finished turn's tool call draws nothing", async ($, on) => {
  engineBeneath(on)
  const props = buildToolUseProps({ tool_use_id: 'TOOL_USE_ID' })
  await runTurn($, ['TOOL_USE_ID'])

  const ui = await mountToolUse($, props)

  expect(await ui.findAll({ type: 'Text' })).toEqual([])
})

test("a finished turn's answer draws as usual", async ($, on) => {
  engineBeneath(on)
  await runTurn($, ['TOOL_USE_ID'])

  const ui = await mountMessage($, ANSWER_UUID)

  expect((await ui.find({ type: 'Text' }))?.text).toBe(ENGINE_ROW)
})

test("a running turn's tool call draws as usual", async ($, on) => {
  engineBeneath(on)
  const props = buildToolUseProps({ tool_use_id: 'TOOL_USE_ID' })
  await runTurn($, ['TOOL_USE_ID'], { isFinished: false })

  const ui = await mountToolUse($, props)

  expect((await ui.find({ type: 'Text' }))?.text).toBe(ENGINE_ROW)
})

test("/steps draws a finished turn's tool call as usual", async ($, on) => {
  engineBeneath(on)
  const props = buildToolUseProps({ tool_use_id: 'TOOL_USE_ID' })
  await runTurn($, ['TOOL_USE_ID'])

  await $.command.run({
    command: 'steps',
    args: '',
    origin: { kind: 'composer' },
    presentation: { isFullscreen: false, columns: 120 },
  })

  const ui = await mountToolUse($, props)
  expect((await ui.find({ type: 'Text' }))?.text).toBe(ENGINE_ROW)
})
