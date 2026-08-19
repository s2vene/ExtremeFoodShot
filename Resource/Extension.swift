//
//  Pretendard+Extension.swift
//  Maju
//
//  Created by 김정훈 on 7/18/26.
//

// MARK: - 프리텐다드 폰트 자율지정 익스텐션

// .font(.Pretendard(weight: ,size: )) 의 형식으로 Text에 작성 및 사용하시면 됩니다.

import SwiftUI

extension Font {
    
    enum Pretendard_Weight: String {
        case Black = "Pretendard-Black"
        case Bold = "Pretendard-Bold"
        case ExtraBold = "Pretendard-ExtraBold"
        case ExtraLight = "Pretendard-ExtraLight"
        case Light = "Pretendard-Light"
        case Medium = "Pretendard-Medium"
        case Regular = "Pretendard-Regular"
        case SemiBold = "Pretendard-SemiBold"
        case Thin = "Pretendard-Thin"
    }
    
    static func Pretendard(
        weight : Pretendard_Weight = .Medium,
        size : CGFloat
    ) -> Font {
        .custom(weight.rawValue, size: size)
    }
    
}

// MARK: - 자주 쓰이는 폰트 디자인 시스템 구축

// 사용하기 전, extension 외부 주석을 꼭 제거하고 사용해주세요.


extension Font {
    
    // static let [Fontname] = Font.custom("[Pretendard-Fontweight]", size: [Fontsize])
 
    // [Fontname] : 실제 코드 작성 시, 사용할 이름을 지정합니다. 예) Maintitle
    // [Pretendard-Fontweight] : 사용할 폰트 굵기를 지정합니다. 'Pretendard-'가 꼭 붙어야 합니다. 예) Pretendard-Bold
    // [Fontsize] : 사용할 폰트 크기를 지정합니다. 예) 20
    
    // Figma Text Styles
    static let fsTitle1 = Font.custom("Pretendard-SemiBold", size: 22)
    static let fsTitle2 = Font.custom("Pretendard-SemiBold", size: 18)
    static let fsBody = Font.custom("Pretendard-Regular", size: 16)
    static let fsCaption1 = Font.custom("Pretendard-Regular", size: 14)
    static let fsCaption2 = Font.custom("Pretendard-SemiBold", size: 12)
    
}


extension Color {
    static let fsNavy = Color("fsnavy")
    static let fsLime = Color("fslime")
    static let fsWhite = Color("fswhite")
    static let fsRed = Color("fsred")
}
