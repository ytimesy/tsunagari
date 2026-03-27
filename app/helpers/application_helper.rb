module ApplicationHelper
  def publication_status_label(status)
    {
      "draft" => "下書き",
      "review" => "レビュー中",
      "published" => "公開中",
      "archived" => "アーカイブ"
    }.fetch(status, status)
  end

  def evidence_level_label(level)
    {
      "documented" => "資料確認済み",
      "reported" => "報告ベース",
      "observed" => "観察ベース",
      "hypothesis" => "仮説"
    }.fetch(level, level)
  end

  def outcome_direction_label(direction)
    {
      "positive" => "前進",
      "negative" => "失敗・後退",
      "mixed" => "混合",
      "unresolved" => "未解決"
    }.fetch(direction, direction)
  end

  def insight_type_label(insight_type)
    {
      "enabler" => "前進要因",
      "barrier" => "阻害要因",
      "lesson" => "学び",
      "turning_point" => "転機"
    }.fetch(insight_type, insight_type)
  end

  def role_label(role)
    {
      "editor" => "編集者",
      "admin" => "管理者"
    }.fetch(role, role)
  end
end
