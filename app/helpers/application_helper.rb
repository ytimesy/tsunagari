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

  def role_label(role)
    {
      "editor" => "編集者",
      "admin" => "管理者"
    }.fetch(role, role)
  end
end
