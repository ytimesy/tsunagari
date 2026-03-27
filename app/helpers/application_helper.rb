module ApplicationHelper
  def visibility_label(level)
    {
      "public" => "一般公開",
      "member" => "編集メンバーに公開",
      "private" => "自分だけ"
    }.fetch(level, level)
  end
end
