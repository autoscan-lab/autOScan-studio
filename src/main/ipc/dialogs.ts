import { ipcMain, dialog, BrowserWindow } from 'electron'

export function registerDialogHandlers(): void {
  ipcMain.handle('dialog:open-directory', async (): Promise<string | null> => {
    const win = BrowserWindow.getFocusedWindow()
    const result = await dialog.showOpenDialog(win!, {
      properties: ['openDirectory'],
      title: 'Open Workspace'
    })
    if (result.canceled || result.filePaths.length === 0) return null
    return result.filePaths[0]
  })

  ipcMain.handle(
    'dialog:open-files',
    async (_event, title: string, filters?: Electron.FileFilter[]): Promise<string[]> => {
      const win = BrowserWindow.getFocusedWindow()
      const result = await dialog.showOpenDialog(win!, {
        properties: ['openFile', 'multiSelections'],
        title,
        filters
      })
      if (result.canceled) return []
      return result.filePaths
    }
  )

  ipcMain.handle(
    'dialog:save-file',
    async (
      _event,
      title: string,
      defaultPath?: string,
      filters?: Electron.FileFilter[]
    ): Promise<string | null> => {
      const win = BrowserWindow.getFocusedWindow()
      const result = await dialog.showSaveDialog(win!, {
        title,
        defaultPath,
        filters
      })
      if (result.canceled || !result.filePath) return null
      return result.filePath
    }
  )
}
