import { useState } from 'react'
import { useAppStore } from '../../stores/appStore'

export function PolicyList() {
  const policies = useAppStore((s) => s.policies)
  const selectedPolicyID = useAppStore((s) => s.selectedPolicyID)
  const activePolicyID = useAppStore((s) => s.activePolicyID)
  const selectPolicyForEditing = useAppStore((s) => s.selectPolicyForEditing)
  const createPolicy = useAppStore((s) => s.createPolicy)
  const deletePolicy = useAppStore((s) => s.deletePolicy)
  const [isCreating, setIsCreating] = useState(false)
  const [newName, setNewName] = useState('')

  const handleCreate = () => {
    if (newName.trim()) {
      createPolicy(newName.trim())
      setNewName('')
      setIsCreating(false)
    }
  }

  return (
    <div className="flex flex-col h-full">
      <div className="flex-1 overflow-y-auto py-1">
        {policies.map((policy) => (
          <div
            key={policy.id}
            onClick={() => selectPolicyForEditing(policy.id)}
            className={`
              flex items-center justify-between h-[26px] px-3 cursor-default text-[12px] group
              ${selectedPolicyID === policy.id ? 'bg-selection text-text-primary' : 'text-text-secondary hover:bg-hover hover:text-text-primary'}
            `}
          >
            <span className="truncate flex items-center gap-1.5">
              <span className="text-[13px]">📋</span>
              {policy.name}
              {policy.id === activePolicyID && (
                <span className="text-[10px] text-accent font-medium">active</span>
              )}
            </span>
            <button
              onClick={(e) => {
                e.stopPropagation()
                if (confirm(`Delete policy "${policy.name}"?`)) {
                  deletePolicy(policy.id)
                }
              }}
              className="opacity-0 group-hover:opacity-100 text-text-secondary hover:text-red-400 text-[11px] px-1"
            >
              ✕
            </button>
          </div>
        ))}

        {policies.length === 0 && (
          <p className="text-[11px] text-text-secondary/70 px-3 py-2">No policies yet.</p>
        )}
      </div>

      <div className="border-t border-separator/70 p-2">
        {isCreating ? (
          <div className="flex gap-1.5">
            <input
              autoFocus
              value={newName}
              onChange={(e) => setNewName(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleCreate()
                if (e.key === 'Escape') setIsCreating(false)
              }}
              placeholder="Policy name…"
              className="flex-1 bg-canvas rounded px-2 py-1 text-[12px] text-text-primary outline-none border border-separator focus:border-accent"
            />
            <button
              onClick={handleCreate}
              className="text-[11px] text-accent hover:text-accent-hover px-1.5"
            >
              Add
            </button>
          </div>
        ) : (
          <button
            onClick={() => setIsCreating(true)}
            className="w-full text-[11px] text-text-secondary hover:text-text-primary py-1 cursor-default"
          >
            + New Policy
          </button>
        )}
      </div>
    </div>
  )
}
