class RepresentativeFieldCatalog
  GROUPS = [
    {
      label: "社会・公共",
      fields: %w[
        政治 行政 外交 国際協力 法律 人権 公共政策 地方創生 防災 安全保障
      ]
    },
    {
      label: "経済・産業",
      fields: %w[
        経済学 金融 投資 企業経営 起業 中小企業 流通 貿易 労働 消費市場
      ]
    },
    {
      label: "科学・基礎研究",
      fields: %w[
        数学 物理学 化学 地球科学 天文学 情報科学 統計学 認知科学 材料科学 複雑系科学
      ]
    },
    {
      label: "生命・医療",
      fields: %w[
        医学 看護 公衆衛生 薬学 生物学 バイオテクノロジー 遺伝学 栄養学 精神保健 リハビリテーション
      ]
    },
    {
      label: "工学・技術",
      fields: %w[
        機械工学 電気電子工学 通信 半導体 ロボティクス AI ソフトウェア インフラ工学 宇宙技術 サイバーセキュリティ
      ]
    },
    {
      label: "環境・資源",
      fields: %w[
        気候変動 エネルギー 再生可能エネルギー 脱炭素 生態系保全 農業 林業 水産 水資源 資源循環
      ]
    },
    {
      label: "教育・学習",
      fields: %w[
        学校教育 高等教育 教育政策 生涯学習 EdTech 職業教育 研究教育 子ども支援 特別支援教育 国際教育
      ]
    },
    {
      label: "文化・表現",
      fields: %w[
        文学 哲学 歴史 宗教 美術 音楽 映画 演劇 デザイン 建築
      ]
    },
    {
      label: "メディア・情報流通",
      fields: %w[
        出版 報道 雑誌 放送 インターネットメディア SNS YouTube 広報 ジャーナリズム コンテンツ制作
      ]
    },
    {
      label: "暮らし・コミュニティ",
      fields: %w[
        福祉 子育て ジェンダー 高齢社会 移民・多文化共生 まちづくり 観光 スポーツ 食 ライフスタイル
      ]
    }
  ].freeze

  def self.groups
    GROUPS.map do |group|
      {
        label: group.fetch(:label),
        fields: group.fetch(:fields).dup
      }
    end
  end

  def self.field_names
    groups.flat_map { |group| group.fetch(:fields) }
  end

  def self.count
    field_names.count
  end

  def self.sync_tags!
    field_names.each do |field_name|
      Tag.find_or_initialize_by(normalized_name: field_name.downcase).tap do |tag|
        tag.name = field_name
        tag.save!
      end
    end
  end
end
