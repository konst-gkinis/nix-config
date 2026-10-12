/** The rows of one finished turn that draw collapsed. */
export type CollapsedTurn = {
  /** The row that draws the summary line: the turn's first step. */
  head: string
  /** Every step row id: tool_use_ids and narration message ids. */
  ids: string[]
  /** How many tool calls the turn made. */
  calls: number
}

/** The turn in progress: its step rows so far, in order. */
export type OpenTurn = {
  turnId: string
  ids: string[]
  calls: number
  /** The latest text row; the turn's answer if nothing follows it. */
  lastText: string | null
}

declare module 'claude-code' {
  interface PluginState {
    'collapse-steps': {
      turns: CollapsedTurn[]
      open: OpenTurn | null
      isExpanded: boolean
    }
  }
}
