import type { Cursor, PaneDiffFrame, PaneSnapshotFrame } from "@sterm/protocol-client";

export interface RenderModel {
  paneId: string;
  seq: number;
  rows: number;
  cols: number;
  cursor: Cursor;
  cells: string;
  dirtyRows: Set<number>;
}

export function createRenderModel(snapshot: PaneSnapshotFrame): RenderModel {
  return {
    paneId: snapshot.pane_id,
    seq: snapshot.seq,
    rows: snapshot.rows,
    cols: snapshot.cols,
    cursor: snapshot.cursor,
    cells: snapshot.cells,
    dirtyRows: new Set(Array.from({ length: snapshot.rows }, (_, row) => row)),
  };
}

export function applyPaneDiff(model: RenderModel, diff: PaneDiffFrame): RenderModel {
  if (model.paneId !== diff.pane_id) {
    throw new Error(`Pane diff ${diff.pane_id} does not match model ${model.paneId}`);
  }
  if (diff.seq <= model.seq) {
    return model;
  }
  const dirtyRows = new Set(model.dirtyRows);
  for (const row of diff.dirty_rows) {
    dirtyRows.add(row.row);
  }
  return {
    ...model,
    seq: diff.seq,
    cursor: diff.cursor,
    dirtyRows,
  };
}

export interface AnimationScheduler {
  requestFrame(callback: () => void): void;
}

export class DirtyRegionRenderer {
  private scheduled = false;

  constructor(private readonly scheduler: AnimationScheduler) {}

  scheduleFlush(flush: () => void): void {
    if (this.scheduled) return;
    this.scheduled = true;
    this.scheduler.requestFrame(() => {
      this.scheduled = false;
      flush();
    });
  }
}

export type DirtyRegionReason = "snapshot" | "diff" | "cursor" | "selection" | "search";

export interface DirtyRegion {
  row: number;
  colStart: number;
  colEnd: number;
  reason: DirtyRegionReason;
}

export interface RendererMetrics {
  rows: number;
  cols: number;
  devicePixelRatio: number;
  cellWidth: number;
  cellHeight: number;
}

export interface PaneRenderState {
  paneId: string;
  seq: number;
  rows: number;
  cols: number;
  cells: string;
  cursor: Cursor;
  dirtyRegions: DirtyRegion[];
  scrollback: PaneSnapshotFrame["scrollback"];
}

export interface CanvasRenderCommand {
  kind: "clear" | "paint-cells" | "paint-cursor" | "paint-selection" | "paint-search-highlight";
  paneId: string;
  region: DirtyRegion;
}

export type FrameScheduler = (callback: FrameRequestCallback) => number;

export function createPaneRenderState(snapshot: PaneSnapshotFrame): PaneRenderState {
  return {
    paneId: snapshot.pane_id,
    seq: snapshot.seq,
    rows: snapshot.rows,
    cols: snapshot.cols,
    cells: snapshot.cells,
    cursor: snapshot.cursor,
    scrollback: snapshot.scrollback,
    dirtyRegions: Array.from({ length: snapshot.rows }, (_, row) => ({ row, colStart: 0, colEnd: snapshot.cols, reason: "snapshot" as const })),
  };
}

export function consumeDirtyRegions(state: PaneRenderState): [PaneRenderState, DirtyRegion[]] {
  return [{ ...state, dirtyRegions: [] }, state.dirtyRegions];
}

export function mergeDirtyRegions(regions: DirtyRegion[]): DirtyRegion[] {
  const merged: DirtyRegion[] = [];
  for (const region of [...regions].sort((a, b) => a.row - b.row || a.colStart - b.colStart)) {
    const last = merged.at(-1);
    if (last && last.row === region.row && last.reason === region.reason && region.colStart <= last.colEnd) {
      last.colEnd = Math.max(last.colEnd, region.colEnd);
    } else {
      merged.push({ ...region });
    }
  }
  return merged;
}

export function applyPaneRenderDiff(state: PaneRenderState, diff: PaneDiffFrame): PaneRenderState {
  if (diff.pane_id !== state.paneId) {
    throw new Error(`Cannot apply diff for ${diff.pane_id} to pane ${state.paneId}`);
  }
  if (diff.seq <= state.seq) return state;
  return {
    ...state,
    seq: diff.seq,
    cursor: diff.cursor,
    cells: `${state.cells}|diff:${diff.seq}`,
    dirtyRegions: mergeDirtyRegions([
      ...state.dirtyRegions,
      ...diff.dirty_rows.map((row) => ({ row: row.row, colStart: 0, colEnd: state.cols, reason: "diff" as const })),
      { row: diff.cursor.row, colStart: diff.cursor.col, colEnd: diff.cursor.col + 1, reason: "cursor" as const },
    ]),
  };
}

export function buildCanvasCommands(state: PaneRenderState | RenderModel): CanvasRenderCommand[] {
  const regions = "dirtyRegions" in state
    ? state.dirtyRegions
    : Array.from(state.dirtyRows, (row) => ({ row, colStart: 0, colEnd: state.cols, reason: "diff" as const }));
  return regions.flatMap((region) => {
    const commands: CanvasRenderCommand[] = [{ kind: "paint-cells", paneId: state.paneId, region }];
    if (region.row === state.cursor.row) commands.push({ kind: "paint-cursor", paneId: state.paneId, region });
    return commands;
  });
}

export function scheduleRender(scheduler: FrameScheduler, render: () => void): number {
  return scheduler(() => render());
}

export function defaultRendererMetrics(rows: number, cols: number, devicePixelRatio = 1): RendererMetrics {
  return { rows, cols, devicePixelRatio, cellWidth: 9 * devicePixelRatio, cellHeight: 18 * devicePixelRatio };
}
