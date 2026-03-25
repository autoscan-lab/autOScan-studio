import { registerWorkspaceHandlers } from './workspace'
import { registerDialogHandlers } from './dialogs'
import { registerEngineHandlers } from './engine'
import { registerStoreHandlers } from './store'

export function registerIpcHandlers(): void {
  registerWorkspaceHandlers()
  registerDialogHandlers()
  registerEngineHandlers()
  registerStoreHandlers()
}
