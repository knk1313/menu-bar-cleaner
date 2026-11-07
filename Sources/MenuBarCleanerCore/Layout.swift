import CoreGraphics

/// 区切りの状態アイコンの長さと、並び順の判定。
///
/// 隠す仕組み：区切りの状態アイコンの長さを大きくすると、その左にある状態アイコンが
/// 画面の左端より外へ押し出され、macOS が表示しなくなる。長さを戻すと再び表示される。
public enum Layout {
    /// 展開しているときの区切りの長さ（細い縦線を描く幅）
    public static let expandedSeparatorLength: CGFloat = 14

    /// NSStatusItem.length の上限として扱う値
    public static let maxSeparatorLength: CGFloat = 10_000

    /// 折りたたむときの区切りの長さ。
    ///
    /// 最も広い画面の幅より長ければ、区切りの左にある項目はすべて画面の外に出る。
    /// 必要以上に長くしない（長すぎると macOS の版によっては区切りが捨てられるという報告がある）。
    public static func collapsedSeparatorLength(screenWidths: [CGFloat]) -> CGFloat {
        let widest = screenWidths.max() ?? 0
        return min(maxSeparatorLength, max(1_000, widest + 200))
    }

    /// 区切りがトグルボタンの左にあるか。右にあると、折りたたんだときにトグルボタン自体が隠れる。
    public static func isOrderValid(separatorMinX: CGFloat, toggleMinX: CGFloat) -> Bool {
        separatorMinX < toggleMinX
    }

    /// 境目（区切りの左端）より左にある、つまり隠す対象の項目かどうか。
    /// 座標はどちらも画面の左端を 0 とする x 座標で渡す。
    public static func isHidden(itemFrame: CGRect, boundaryMinX: CGFloat) -> Bool {
        itemFrame.midX < boundaryMinX
    }
}
