//
//  CodeStudyWidgetBundle.swift
//  CodeStudyWidget
//
//  Created by Tabber on 4/6/26.
//

import WidgetKit
import SwiftUI

@main
struct CodeStudyWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodeStudyWidget()
        CodeStudyWidgetControl()
        CodeStudyWidgetLiveActivity()
    }
}
