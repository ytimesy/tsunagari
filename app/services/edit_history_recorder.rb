class EditHistoryRecorder
  def self.record!(item:, action:, summary:, details: {})
    item.edit_histories.create!(
      action: action,
      summary: summary,
      details: details.presence || {}
    )
  end
end
