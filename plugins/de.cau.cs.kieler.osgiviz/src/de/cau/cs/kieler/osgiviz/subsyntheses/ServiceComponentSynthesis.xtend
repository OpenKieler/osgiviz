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
import de.cau.cs.kieler.klighd.krendering.extensions.KPortExtensions
import de.cau.cs.kieler.klighd.syntheses.AbstractSubSynthesis
import de.cau.cs.kieler.osgiviz.OsgiStyles
import de.cau.cs.kieler.osgiviz.osgivizmodel.ServiceComponentContext
import de.cau.cs.kieler.osgiviz.osgivizmodel.ServiceOverviewContext
import de.scheidtbachmann.osgimodel.OsgiProject
import de.scheidtbachmann.osgimodel.ServiceComponent
import org.eclipse.elk.core.options.CoreOptions
import org.eclipse.elk.core.options.PortConstraints
import org.eclipse.elk.core.options.PortSide

import static de.cau.cs.kieler.osgiviz.OsgiOptions.*

/**
 * Sub-synthesis of {@link OsgiProject}s that handles expanded {@link ServiceComponent} views.
 * 
 * @author nre
 */
class ServiceComponentSynthesis extends AbstractSubSynthesis<ServiceComponentContext, KNode> {
    @Inject extension KNodeExtensions
    @Inject extension KPortExtensions
    @Inject extension OsgiStyles
    extension KGraphFactory = KGraphFactory.eINSTANCE
    
    override transform(ServiceComponentContext sc) {
        val serviceComponent = sc.modelElement
        return #[
            sc.createNode() => [
                addLayoutParam(CoreOptions::PORT_CONSTRAINTS, PortConstraints::FIXED_SIDE)
                associateWith(sc)
                data += createKIdentifier => [ it.id = sc.hashCode.toString ]
                
                // The port that shows the connection to the service interfaces this service component implements with
                // actions to add them to the view.
                val interfaces = serviceComponent.serviceInterfaces
                if (!interfaces.empty) {
                    // Port for connecting to implemented service interfaces.
                    ports += createPort(sc, "implementedServiceInterfaces") => [
                        associateWith(sc)
                        // Identifier helps for connecting to this port later.
                        data += createKIdentifier => [ it.id = "implementedServiceInterfaces" ]
                        // Implemented interfaces are always shown and expanded to the east with the drawing
                        // direction.
                        addLayoutParam(CoreOptions::PORT_SIDE, PortSide::EAST)
                        
                        val boolean allImplementingInterfacesShown = if (usedContext.getOptionValue(
                            SERVICE_CONNECTION_VISUALIZATION_IN_BUNDLES) as Boolean) {
                            sc.allImplementedInterfacesShownInBundles
                        } else {
                            sc.allImplementedInterfacesShownPlain
                        }
                            
                        addImplementedServiceInterfacesPortRendering(interfaces.size, allImplementingInterfacesShown)
                        width = 12
                        height = 12
                    ]
                    
                }
                // The port that shows the connection to the service interfaces this service component references with
                // actions to add them to the view.
                val references = serviceComponent.reference
                if (!references.empty) {
                    // Port for connecting to referenced service interfaces.
                    ports += createPort(sc, "referencedServiceInterfaces") => [
                        associateWith(sc)
                        // Identifier for connecting to this port.
                        data += createKIdentifier => [ it.id = "referencedServiceInterfaces" ]
                        // Referenced interfaces are always shown and expanded to the west against the drawing
                        // direction.
                        addLayoutParam(CoreOptions::PORT_SIDE, PortSide::WEST)
                        
                        val boolean allReferencedInterfacesShown = if (usedContext.getOptionValue(
                            SERVICE_CONNECTION_VISUALIZATION_IN_BUNDLES) as Boolean) {
                            sc.allReferencedInterfacesShownInBundles
                        } else {
                            sc.allReferencedInterfacesShownPlain
                        }
                        
                        addReferencedServiceInterfacesPortRendering(references.size, allReferencedInterfacesShown)
                        width = 12
                        height = 12
                    ]
                }
                
                // Add the rendering.
                val hasChildren = !children.empty
                addServiceComponentRendering(serviceComponent,
                    sc.parent instanceof ServiceOverviewContext, hasChildren, usedContext)
            ]
        ]
    }
    
}
