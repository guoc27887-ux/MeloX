import Foundation

func localizedPlaylistCategory(_ category: String) -> String {
    let key: String
    switch category {
    case "推荐歌单": key = "ui.category.recommended_playlists"
    case "排行榜": key = "ui.category.toplists"
    case "精品歌单": key = "ui.category.featured_playlists"
    case "全部": key = "ui.category.all"
    case "华语": key = "ui.category.chinese"
    case "欧美": key = "ui.category.europe_america"
    case "日语": key = "ui.category.japanese"
    case "韩语": key = "ui.category.korean"
    case "粤语": key = "ui.category.cantonese"
    case "流行": key = "ui.category.pop"
    case "摇滚": key = "ui.category.rock"
    case "民谣": key = "ui.category.folk"
    case "电子": key = "ui.category.electronic"
    case "说唱": key = "ui.category.hip_hop"
    case "R&B/Soul": key = "ui.category.rnb_soul"
    case "古典": key = "ui.category.classical"
    case "ACG": key = "ui.category.acg"
    case "影视原声": key = "ui.category.soundtrack"
    case "轻音乐": key = "ui.category.easy_listening"
    case "学习": key = "ui.category.study"
    case "工作": key = "ui.category.work"
    case "放松": key = "ui.category.relax"
    case "夜晚": key = "ui.category.night"
    default: return category
    }
    return L10n.string(key)
}
