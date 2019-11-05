package de.cau.cs.kieler.osgiviz

import com.google.common.collect.ImmutableList
import com.google.inject.Inject
import de.cau.cs.kieler.klighd.DisplayedActionData
import de.cau.cs.kieler.klighd.kgraph.KGraphFactory
import de.cau.cs.kieler.klighd.krendering.ViewSynthesisShared
import de.cau.cs.kieler.klighd.krendering.extensions.KNodeExtensions
import de.cau.cs.kieler.klighd.syntheses.AbstractDiagramSynthesis
import de.scheidtbachmann.osgimodel.OsgiProject
import de.cau.cs.kieler.osgiviz.actions.RedoAction
import de.cau.cs.kieler.osgiviz.actions.ResetViewAction
import de.cau.cs.kieler.osgiviz.actions.ToggleServiceComponentVisualization
import de.cau.cs.kieler.osgiviz.actions.UndoAction
import de.cau.cs.kieler.osgiviz.context.BundleCategoryOverviewContext
import de.cau.cs.kieler.osgiviz.context.BundleOverviewContext
import de.cau.cs.kieler.osgiviz.context.ContextUtils
import de.cau.cs.kieler.osgiviz.context.FeatureOverviewContext
import de.cau.cs.kieler.osgiviz.context.IVisualizationContext
import de.cau.cs.kieler.osgiviz.context.OsgiProjectContext
import de.cau.cs.kieler.osgiviz.context.PackageObjectOverviewContext
import de.cau.cs.kieler.osgiviz.context.ProductOverviewContext
import de.cau.cs.kieler.osgiviz.context.ServiceComponentOverviewContext
import de.cau.cs.kieler.osgiviz.context.ServiceInterfaceOverviewContext
import de.cau.cs.kieler.osgiviz.subsyntheses.BundleCategoryOverviewSynthesis
import de.cau.cs.kieler.osgiviz.subsyntheses.BundleOverviewSynthesis
import de.cau.cs.kieler.osgiviz.subsyntheses.FeatureOverviewSynthesis
import de.cau.cs.kieler.osgiviz.subsyntheses.PackageObjectOverviewSynthesis
import de.cau.cs.kieler.osgiviz.subsyntheses.ProductOverviewSynthesis
import de.cau.cs.kieler.osgiviz.subsyntheses.ServiceComponentOverviewSynthesis
import de.cau.cs.kieler.osgiviz.subsyntheses.ServiceInterfaceOverviewSynthesis
import java.util.LinkedHashSet
import org.eclipse.elk.alg.layered.options.CrossingMinimizationStrategy
import org.eclipse.elk.alg.layered.options.LayeredMetaDataProvider
import org.eclipse.elk.alg.layered.options.LayeredOptions

import static de.cau.cs.kieler.osgiviz.OsgiOptions.*

/**
 * Main diagram synthesis for {@link OsgiProject} models.
 * 
 * @author nre
 */
@ViewSynthesisShared
class OsgiDiagramSynthesis extends AbstractDiagramSynthesis<OsgiProject> {
    @Inject extension KNodeExtensions
    @Inject extension OsgiStyles
    
    @Inject BundleCategoryOverviewSynthesis bundleCategoryOverviewSynthesis
    @Inject BundleOverviewSynthesis bundleOverviewSynthesis
    @Inject FeatureOverviewSynthesis featureOverviewSynthesis
    @Inject PackageObjectOverviewSynthesis packageObjectOverviewSynthesis
    @Inject ProductOverviewSynthesis productOverviewSynthesis
    @Inject ServiceInterfaceOverviewSynthesis serviceInterfaceOverviewSynthesis
    @Inject ServiceComponentOverviewSynthesis serviceComponentOverviewSynthesis
    
    extension KGraphFactory = KGraphFactory.eINSTANCE
    
    override getInputDataType() {
        OsgiProject
    }
    
    override getDisplayedActions() {
        return #[
            DisplayedActionData.create(UndoAction.ID, "Undo",
                "Undoes the last action performed on the view model."),
            DisplayedActionData.create(RedoAction.ID, "Redo",
                "Redoes the last action that was undone on the view model."),
            DisplayedActionData.create(ResetViewAction.ID, "Reset View",
                "Resets the view to its default overview state."),
            DisplayedActionData.create(ToggleServiceComponentVisualization.ID, "Toggle service component visualization",
                "Toggles between visualizing service components on their own and visualizing them in their bundle "
                + "context.\n\n"
                + "To be able to view the service components in the bundles, the Bundle->Show Service Components "
                + "option has to be turned on.")
        ]
    }
    
    override getDisplayedLayoutOptions() {
        return ImmutableList::of(
            specifyLayoutOption(LayeredOptions::HIGH_DEGREE_NODES_TREATMENT, #[true, false]),
            specifyLayoutOption(LayeredMetaDataProvider::CROSSING_MINIMIZATION_STRATEGY,
                #[CrossingMinimizationStrategy.INTERACTIVE, CrossingMinimizationStrategy.LAYER_SWEEP])
        )
    }
       
    override getDisplayedSynthesisOptions() {
        val options = new LinkedHashSet()
        
        // Add category options.
        options.addAll(FILTER_CATEGORY, TEXT_FILTER_CATEGORY, VIEW_FILTER_CATEGORY)
        
        // Add general options.
        options.addAll(SIMPLE_TEXT)
        
        // Add all text filter options.
        options.addAll(FILTER_BY, FILTER_BUNDLE_CATEGORIES, FILTER_BUNDLES, FILTER_FEATURES,
            FILTER_PACKAGE_OBJECTS, FILTER_PRODUCTS, FILTER_SERVICE_COMPONENTS, FILTER_SERVICE_INTERFACES)
        
        // Add all view filter options.
        options.addAll(SHOW_EXTERNAL, BUNDLE_SHOW_SERVICE_COMPONENTS, FILTER_CARDINALITY_LABEL, FILTER_DESCRIPTIONS,
            DESCRIPTION_LENGTH, SHORTEN_BY)
        
        return options.toList
    }
    
    override transform(OsgiProject model) {
        val modelNode = createNode.associateWith(model)
        
        // Create a view with the currently stored visualization context in mind. If there is no current context, create
        // a new one for the general OSGi model overview and store that for later use.
        val visualizationContexts = usedContext.getProperty(OsgiSynthesisProperties.VISUALIZATION_CONTEXTS)
        var index = usedContext.getProperty(OsgiSynthesisProperties.CURRENT_VISUALIZATION_CONTEXT_INDEX)
        var IVisualizationContext<?> visualizationContext = null
        
        if (!visualizationContexts.empty && index !== null) {
            visualizationContext = visualizationContexts.get(index)
        }
        // If the visualization context is for another model than the model this method was called for or does not exist
        // yet, reset the contexts.
        if (visualizationContext === null || !ContextUtils.isRootModel(visualizationContext, model)) {
            visualizationContexts.removeIf [ true ]
            index = 0
            usedContext.setProperty(OsgiSynthesisProperties.CURRENT_VISUALIZATION_CONTEXT_INDEX, index)
            visualizationContext = new OsgiProjectContext(model, null)
            visualizationContexts.add(visualizationContext)
        }

        // Make this variable final here for later usage in the lambda.
        val visContext = visualizationContext
        if (visContext instanceof OsgiProjectContext) {
            // This synthesis can be used.
            
            // The overview of the entire OSGi Project.
            modelNode.children += createNode => [
                associateWith(model)
                data += createKIdentifier => [ it.id = visContext.hashCode.toString ]
                addProjectRendering
                
                val overviewProductNodes = productOverviewSynthesis.transform(visContext.productOverviewContext)
                children += overviewProductNodes
                
                val overviewFeatureNodes = featureOverviewSynthesis.transform(visContext.featureOverviewContext)
                children += overviewFeatureNodes
                
                val overviewBundleNodes = bundleOverviewSynthesis.transform(visContext.bundleOverviewContext)
                children += overviewBundleNodes
                
                val overviewServiceInterfaceNodes = serviceInterfaceOverviewSynthesis.transform(
                    visContext.serviceInterfaceOverviewContext)
                children += overviewServiceInterfaceNodes
                
//                val overviewImportedPackagesNodes = packageObjectOverviewSynthesis.transform(
//                    visContext.importedPackageOverviewContext)
//                children += overviewImportedPackagesNodes
                
                val overviewBundleCategoryNodes = bundleCategoryOverviewSynthesis.transform(
                    visContext.bundleCategoryOverviewContext)
                children += overviewBundleCategoryNodes
            ]
            
            return modelNode
            
        } else {
            // Delegate the view model generation to another subsynthesis that can show the requested visualization context.
            val children = transformSubModel(visualizationContext)
            
            modelNode.children += children
            
            return modelNode
        }
    }
    
    private def transformSubModel(IVisualizationContext<?> context) {
        switch (context) {
            BundleCategoryOverviewContext: {
                return bundleCategoryOverviewSynthesis.transform(context as BundleCategoryOverviewContext)
            }
            BundleOverviewContext: {
                return bundleOverviewSynthesis.transform(context as BundleOverviewContext)
            }
            FeatureOverviewContext: {
                return featureOverviewSynthesis.transform(context as FeatureOverviewContext)
            }
            PackageObjectOverviewContext: {
                return packageObjectOverviewSynthesis.transform(context as PackageObjectOverviewContext)
            }
            ProductOverviewContext: {
                return productOverviewSynthesis.transform(context as ProductOverviewContext)
            }
            ServiceInterfaceOverviewContext: {
                return serviceInterfaceOverviewSynthesis.transform(context as ServiceInterfaceOverviewContext)
            }
            ServiceComponentOverviewContext: {
                return serviceComponentOverviewSynthesis.transform(context as ServiceComponentOverviewContext)
            }
            default: {
                throw new IllegalArgumentException("The context class has no known subsynthesis: " + context.class)
            }
        }
    }
    
}
