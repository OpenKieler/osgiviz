/*
 * OsgiViz - Kieler Visualization for Projects using the OSGi Technology
 * 
 * A part of kieler
 * https://github.com/kieler
 * 
 * Copyright 2019 by
 * + Christian-Albrechts-University of Kiel
 *   + Department of Computer Science
 *     + Real-Time and Embedded Systems Group
 * 
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 * 
 * SPDX-License-Identifier: EPL-2.0
 */
package de.cau.cs.kieler.osgiviz.subsyntheses

import com.google.inject.Inject
import de.cau.cs.kieler.klighd.kgraph.KGraphFactory
import de.cau.cs.kieler.klighd.kgraph.KNode
import de.cau.cs.kieler.klighd.krendering.extensions.KNodeExtensions
import de.cau.cs.kieler.klighd.syntheses.AbstractSubSynthesis
import de.cau.cs.kieler.osgiviz.OsgiOptions.SimpleTextType
import de.cau.cs.kieler.osgiviz.OsgiStyles
import de.cau.cs.kieler.osgiviz.SynthesisUtils
import de.cau.cs.kieler.osgiviz.osgivizmodel.FeatureContext
import org.eclipse.elk.core.options.CoreOptions

import static de.cau.cs.kieler.osgiviz.OsgiOptions.*

import static extension de.cau.cs.kieler.klighd.syntheses.DiagramSyntheses.*

/**
 * Transformation of a simple view of a feature that provides functionality to be expanded, when the specific 
 * synthesis for features is called.
 * 
 * @author nre
 */
class SimpleFeatureSynthesis extends AbstractSubSynthesis<FeatureContext, KNode> {
    @Inject extension KNodeExtensions
    @Inject extension OsgiStyles
    extension KGraphFactory = KGraphFactory.eINSTANCE
    
    override transform(FeatureContext fc) {
        transform(fc, 0)
    }
    
    def transform(FeatureContext fc, int priority) {
        val feature = fc.modelElement
        return #[
            fc.createNode() => [
                associateWith(fc)
                data += createKIdentifier => [ it.id = fc.hashCode.toString ]
                val label = switch usedContext.getOptionValue(SIMPLE_TEXT) {
                    case SimpleTextType.Id: {
                        SynthesisUtils.getId(feature.uniqueId, usedContext)
                    }
                    case SimpleTextType.Name: {
                        feature.descriptiveName
                    }
                } ?: ""
                setLayoutOption(CoreOptions::PRIORITY, priority)
                addFeatureInOverviewRendering(feature, label, usedContext)
            ]
        ]
    }
    
}
